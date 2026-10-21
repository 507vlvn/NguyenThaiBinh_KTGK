namespace NguyenThaiBinh.model;

// Lên lịch một buổi học (chưa mở điểm danh).
public record SessionRequest(string Title, DateTime StartsAt, DateTime? EndsAt);

// Tạo lịch nhiều buổi lặp lại (mặc định hằng tuần) bắt đầu từ FirstStartsAt (UTC).
public record GenerateSessionsRequest(DateTime FirstStartsAt, int DurationMinutes, int Count, int IntervalDays = 7);

// Mở điểm danh tại lớp. DurationMinutes bỏ trống = mở đến khi giảng viên đóng.
public record OpenSessionRequest(double Latitude, double Longitude, double RadiusMeters, int? DurationMinutes = null);

public record ManualCheckInRequest(int StudentId);

public record ReopenRequest(int Minutes = 15);

// Điểm danh gửi dạng multipart/form-data vì có kèm ảnh.
public class CheckInForm
{
    public string QrToken { get; set; } = "";
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public IFormFile? Photo { get; set; }
}
