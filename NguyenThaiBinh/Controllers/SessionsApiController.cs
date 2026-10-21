using System.Security.Cryptography;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using NguyenThaiBinh.model;
using NguyenThaiBinh.Repositories;
using NguyenThaiBinh.Services;

namespace NguyenThaiBinh.Controllers;

[ApiController]
[Authorize]
public class SessionsApiController(
    ISessionRepository sessions,
    IClassRepository classes,
    ILeaveRequestRepository leaves,
    FileStorageService files) : ApiControllerBase
{
    private const string NoClassAccess = "Không tìm thấy lớp hoặc bạn không có quyền.";

    // Lịch buổi học của lớp, sắp theo giờ học.
    // Giảng viên/admin nhận mã QR và số sinh viên có mặt; sinh viên nhận trạng thái của chính mình.
    [HttpGet("api/classes/{classId:int}/sessions")]
    public async Task<IActionResult> GetByClass(int classId)
    {
        var c = await classes.FindManagedAsync(classId, CurrentUserId, IsAdmin);
        if (c is null && !await classes.IsEnrolledAsync(classId, CurrentUserId)) return NotFound();

        var owner = c is not null;
        var now = DateTime.UtcNow;
        var list = await sessions.Sessions().Where(s => s.ClassRoomId == classId)
            .OrderBy(s => s.StartsAt)
            .ToListAsync();

        var classAttendances = sessions.Attendances().Where(a => a.ClassSession.ClassRoomId == classId);
        var presentCounts = owner
            ? await classAttendances.GroupBy(a => a.ClassSessionId).Select(g => new { g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Key, x => x.Count)
            : new Dictionary<int, int>();
        var attended = owner
            ? []
            : (await classAttendances.Where(a => a.StudentId == CurrentUserId).Select(a => a.ClassSessionId).ToListAsync())
                .ToHashSet();
        var myLeaves = owner
            ? new Dictionary<int, LeaveStatus>()
            : await leaves.LeaveRequests()
                .Where(l => l.StudentId == CurrentUserId && l.ClassSession.ClassRoomId == classId)
                .ToDictionaryAsync(l => l.ClassSessionId, l => l.Status);

        return Ok(list.Select(s => new
        {
            s.Id, s.Title, s.StartsAt, s.EndsAt, s.OpenedAt, s.CheckInUntil, s.RadiusMeters,
            State = s.State(now),
            IsOpen = s.AcceptsCheckIn(now),
            QrToken = owner && s.OpenedAt != null ? s.QrToken : null,
            PresentCount = owner ? presentCounts.GetValueOrDefault(s.Id) : (int?)null,
            CheckedIn = attended.Contains(s.Id),
            LeaveStatus = myLeaves.TryGetValue(s.Id, out var status) ? status.ToString() : null
        }));
    }

    // Lên lịch một buổi học (chưa mở điểm danh).
    [HttpPost("api/classes/{classId:int}/sessions")]
    public async Task<IActionResult> Create(int classId, SessionRequest req)
    {
        if (await classes.FindManagedAsync(classId, CurrentUserId, IsAdmin) is null) return NotFound(NoClassAccess);
        var error = Validate(req);
        if (error is not null) return BadRequest(error);

        var s = new ClassSession
        {
            ClassRoomId = classId,
            Title = req.Title.Trim(),
            StartsAt = req.StartsAt,
            EndsAt = req.EndsAt,
            QrToken = NewToken()
        };
        sessions.AddSession(s);
        await sessions.SaveAsync();
        return Ok(ToDto(s));
    }

    // Tạo lịch nhiều buổi lặp lại, đặt tên tiếp nối "Buổi N".
    [HttpPost("api/classes/{classId:int}/sessions/generate")]
    public async Task<IActionResult> Generate(int classId, GenerateSessionsRequest req)
    {
        if (await classes.FindManagedAsync(classId, CurrentUserId, IsAdmin) is null) return NotFound(NoClassAccess);
        if (req.Count is < 1 or > 60) return BadRequest("Số buổi phải từ 1 đến 60.");
        if (req.DurationMinutes is < 15 or > 600) return BadRequest("Thời lượng buổi học phải từ 15 đến 600 phút.");
        if (req.IntervalDays is < 1 or > 30) return BadRequest("Khoảng cách giữa các buổi phải từ 1 đến 30 ngày.");

        var existing = await sessions.Sessions().CountAsync(s => s.ClassRoomId == classId);
        for (var i = 0; i < req.Count; i++)
        {
            var start = req.FirstStartsAt.AddDays(req.IntervalDays * i);
            sessions.AddSession(new ClassSession
            {
                ClassRoomId = classId,
                Title = $"Buổi {existing + i + 1}",
                StartsAt = start,
                EndsAt = start.AddMinutes(req.DurationMinutes),
                QrToken = NewToken()
            });
        }
        await sessions.SaveAsync();
        return Ok(new { created = req.Count, message = $"Đã tạo lịch {req.Count} buổi học." });
    }

    // Sửa tên và giờ học của buổi.
    [HttpPut("api/sessions/{id:int}")]
    public async Task<IActionResult> Update(int id, SessionRequest req)
    {
        var s = await FindManagedSessionAsync(id);
        if (s is null) return NotFound();
        var error = Validate(req);
        if (error is not null) return BadRequest(error);

        s.Title = req.Title.Trim();
        s.StartsAt = req.StartsAt;
        s.EndsAt = req.EndsAt;
        await sessions.SaveAsync();
        return Ok(ToDto(s));
    }

    [HttpDelete("api/sessions/{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var s = await FindManagedSessionAsync(id);
        if (s is null) return NotFound();

        sessions.RemoveSession(s);
        if (!await sessions.SaveAsync()) return Conflict("Không thể xoá: buổi học đã có dữ liệu điểm danh hoặc đơn nghỉ.");
        return NoContent();
    }

    // Mở điểm danh tại lớp: lưu vị trí lớp, tạo mã QR mới, đặt hạn điểm danh.
    [HttpPost("api/sessions/{id:int}/open")]
    public async Task<IActionResult> Open(int id, OpenSessionRequest req)
    {
        var s = await FindManagedSessionAsync(id);
        if (s is null) return NotFound();
        if (req.RadiusMeters <= 0) return BadRequest("Bán kính phải lớn hơn 0.");
        if (req.DurationMinutes is < 0 or > 600) return BadRequest("Thời gian điểm danh phải từ 0 đến 600 phút.");

        var now = DateTime.UtcNow;
        s.Latitude = req.Latitude;
        s.Longitude = req.Longitude;
        s.RadiusMeters = req.RadiusMeters;
        s.OpenedAt ??= now;
        s.CheckInUntil = req.DurationMinutes is > 0 ? now.AddMinutes(req.DurationMinutes.Value) : null;
        s.QrToken = NewToken();
        s.IsOpen = true;
        await sessions.SaveAsync();
        return Ok(ToDto(s, includeQr: true));
    }

    [HttpPost("api/sessions/{id:int}/close")]
    public async Task<IActionResult> Close(int id)
    {
        var s = await FindManagedSessionAsync(id);
        if (s is null) return NotFound();

        s.IsOpen = false;
        await sessions.SaveAsync();
        return Ok(new { message = "Đã đóng điểm danh." });
    }

    // Mở lại điểm danh thêm một khoảng thời gian (ví dụ giảng viên lỡ đóng sớm). Giữ vị trí cũ.
    [HttpPost("api/sessions/{id:int}/reopen")]
    public async Task<IActionResult> Reopen(int id, ReopenRequest req)
    {
        var s = await FindManagedSessionAsync(id);
        if (s is null) return NotFound();
        if (s.OpenedAt is null) return BadRequest("Buổi học chưa mở điểm danh lần nào.");
        if (req.Minutes is < 1 or > 240) return BadRequest("Thời gian mở lại phải từ 1 đến 240 phút.");

        s.IsOpen = true;
        s.CheckInUntil = DateTime.UtcNow.AddMinutes(req.Minutes);
        await sessions.SaveAsync();
        return Ok(new { message = $"Đã mở lại điểm danh thêm {req.Minutes} phút.", s.CheckInUntil });
    }

    // Sinh viên quét QR (gửi kèm mã QR), kiểm tra đăng ký lớp, thời gian, khoảng cách GPS và ảnh chụp.
    [HttpPost("api/sessions/{id:int}/check-in")]
    [Authorize(Roles = nameof(UserRole.SinhVien))]
    public async Task<IActionResult> CheckIn(int id, [FromForm] CheckInForm form)
    {
        var s = await sessions.Sessions().FirstOrDefaultAsync(x => x.Id == id);
        if (s is null) return NotFound();
        if (s.OpenedAt is null) return BadRequest("Buổi học chưa mở điểm danh.");
        if (!s.AcceptsCheckIn(DateTime.UtcNow)) return BadRequest("Buổi học đã hết thời gian điểm danh.");
        if (!string.Equals(form.QrToken, s.QrToken, StringComparison.Ordinal))
            return BadRequest("Mã QR không đúng với buổi học này.");
        if (!await classes.IsEnrolledAsync(s.ClassRoomId, CurrentUserId)) return Forbid();
        if (await sessions.Attendances().AnyAsync(a => a.ClassSessionId == id && a.StudentId == CurrentUserId))
            return Conflict("Bạn đã điểm danh buổi này.");

        var distance = GeoHelper.DistanceMeters(s.Latitude, s.Longitude, form.Latitude, form.Longitude);
        if (distance > s.RadiusMeters)
            return BadRequest(new
            {
                message = $"Bạn đang cách lớp khoảng {Math.Round(distance)} m, ngoài phạm vi {Math.Round(s.RadiusMeters)} m cho phép.",
                distanceMeters = Math.Round(distance)
            });

        string? photoPath = null;
        if (form.Photo is { Length: > 0 })
        {
            try
            {
                photoPath = await files.SaveAsync(form.Photo, "attendance");
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        sessions.AddAttendance(new Attendance
        {
            ClassSessionId = id,
            StudentId = CurrentUserId,
            CheckedInAt = DateTime.UtcNow,
            Latitude = form.Latitude,
            Longitude = form.Longitude,
            DistanceMeters = distance,
            PhotoPath = photoPath
        });
        if (!await sessions.SaveAsync()) return Conflict("Bạn đã điểm danh buổi này.");
        return Ok(new { message = "Điểm danh thành công.", distanceMeters = Math.Round(distance) });
    }

    // Danh sách cả lớp cho một buổi: có mặt, có phép, chờ duyệt đơn, vắng.
    [HttpGet("api/sessions/{id:int}/roster")]
    public async Task<IActionResult> GetRoster(int id)
    {
        var s = await FindManagedSessionAsync(id);
        if (s is null) return NotFound();

        var students = await classes.Enrollments().Where(e => e.ClassRoomId == s.ClassRoomId)
            .OrderBy(e => e.Student.FullName)
            .Select(e => new { e.StudentId, e.Student.Username, e.Student.FullName })
            .ToListAsync();
        var attendances = await sessions.Attendances().Where(a => a.ClassSessionId == id)
            .ToDictionaryAsync(a => a.StudentId);
        var leaveStatus = await leaves.LeaveRequests().Where(l => l.ClassSessionId == id)
            .ToDictionaryAsync(l => l.StudentId, l => l.Status);

        return Ok(students.Select(st =>
        {
            attendances.TryGetValue(st.StudentId, out var a);
            var hasLeave = leaveStatus.TryGetValue(st.StudentId, out var leave);
            var status = a is not null ? "Present"
                : hasLeave && leave == LeaveStatus.Approved ? "Excused"
                : hasLeave && leave == LeaveStatus.Pending ? "PendingLeave"
                : "Absent";
            return new
            {
                st.StudentId, st.Username, st.FullName, Status = status,
                AttendanceId = a?.Id, CheckedInAt = a?.CheckedInAt, DistanceMeters = a?.DistanceMeters,
                HasPhoto = a?.PhotoPath != null, IsManual = a?.IsManual ?? false
            };
        }));
    }

    // Giảng viên điểm danh hộ (sinh viên có mặt nhưng không quét được mã).
    [HttpPost("api/sessions/{id:int}/manual-checkin")]
    public async Task<IActionResult> ManualCheckIn(int id, ManualCheckInRequest req)
    {
        var s = await FindManagedSessionAsync(id);
        if (s is null) return NotFound();
        if (s.OpenedAt is null) return BadRequest("Hãy mở điểm danh cho buổi học trước.");
        if (!await classes.IsEnrolledAsync(s.ClassRoomId, req.StudentId)) return BadRequest("Sinh viên không thuộc lớp này.");

        sessions.AddAttendance(new Attendance
        {
            ClassSessionId = id,
            StudentId = req.StudentId,
            CheckedInAt = DateTime.UtcNow,
            Latitude = s.Latitude,
            Longitude = s.Longitude,
            DistanceMeters = 0,
            IsManual = true
        });
        if (!await sessions.SaveAsync()) return Conflict("Sinh viên đã được điểm danh.");
        return Ok(new { message = "Đã điểm danh hộ." });
    }

    // Huỷ lượt điểm danh (giảng viên sửa sai).
    [HttpDelete("api/sessions/{id:int}/attendances/{studentId:int}")]
    public async Task<IActionResult> RemoveAttendance(int id, int studentId)
    {
        if (await FindManagedSessionAsync(id) is null) return NotFound();
        var a = await sessions.Attendances().FirstOrDefaultAsync(x => x.ClassSessionId == id && x.StudentId == studentId);
        if (a is null) return NotFound();

        sessions.RemoveAttendance(a);
        await sessions.SaveAsync();
        return NoContent();
    }

    [HttpGet("api/sessions/{id:int}/attendances")]
    public async Task<IActionResult> GetAttendances(int id)
    {
        if (await FindManagedSessionAsync(id) is null) return NotFound();

        var list = await sessions.Attendances().Where(a => a.ClassSessionId == id)
            .OrderBy(a => a.CheckedInAt)
            .Select(a => new
            {
                a.Id, a.StudentId, a.Student.Username, a.Student.FullName,
                a.CheckedInAt, a.DistanceMeters, a.IsManual, HasPhoto = a.PhotoPath != null
            })
            .ToListAsync();
        return Ok(list);
    }

    [HttpGet("api/attendances/{id:int}/photo")]
    public async Task<IActionResult> GetPhoto(int id)
    {
        var a = await sessions.Attendances().Include(x => x.ClassSession).FirstOrDefaultAsync(x => x.Id == id);
        if (a is null || a.PhotoPath is null) return NotFound();
        if (a.StudentId != CurrentUserId && await classes.FindManagedAsync(a.ClassSession.ClassRoomId, CurrentUserId, IsAdmin) is null)
            return NotFound();

        return PhysicalFile(files.FullPath(a.PhotoPath), FileStorageService.MimeOf(a.PhotoPath));
    }

    private static string NewToken() => Convert.ToHexString(RandomNumberGenerator.GetBytes(16));

    private static object ToDto(ClassSession s, bool includeQr = false)
    {
        var now = DateTime.UtcNow;
        return new
        {
            s.Id, s.Title, s.StartsAt, s.EndsAt, s.OpenedAt, s.CheckInUntil, s.RadiusMeters,
            State = s.State(now),
            IsOpen = s.AcceptsCheckIn(now),
            QrToken = includeQr ? s.QrToken : null
        };
    }

    private static string? Validate(SessionRequest req)
    {
        if (string.IsNullOrWhiteSpace(req.Title)) return "Vui lòng nhập tên buổi học.";
        if (req.EndsAt is not null && req.EndsAt <= req.StartsAt) return "Giờ kết thúc phải sau giờ bắt đầu.";
        return null;
    }

    // Trả về buổi học nếu người dùng là admin hoặc giảng viên của lớp chứa buổi học đó.
    private async Task<ClassSession?> FindManagedSessionAsync(int id)
    {
        var s = await sessions.Sessions().FirstOrDefaultAsync(x => x.Id == id);
        return s is not null && await classes.FindManagedAsync(s.ClassRoomId, CurrentUserId, IsAdmin) is not null ? s : null;
    }
}
