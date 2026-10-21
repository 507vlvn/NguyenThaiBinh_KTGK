namespace NguyenThaiBinh.model;

// Một buổi học trong lịch của lớp.
// Buổi được lên lịch trước (OpenedAt = null); đến giờ học giảng viên mở điểm danh tại lớp.
public class ClassSession
{
    public int Id { get; set; }
    public int ClassRoomId { get; set; }
    public ClassRoom ClassRoom { get; set; } = null!;
    public string Title { get; set; } = "";
    // Giờ học theo lịch.
    public DateTime StartsAt { get; set; }
    public DateTime? EndsAt { get; set; }
    // Lúc giảng viên mở điểm danh; null = chưa mở (buổi sắp diễn ra).
    public DateTime? OpenedAt { get; set; }
    // Hạn điểm danh; null = mở đến khi giảng viên đóng.
    public DateTime? CheckInUntil { get; set; }
    // Vị trí lớp, lấy từ GPS của giảng viên khi mở điểm danh.
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public double RadiusMeters { get; set; }
    public string QrToken { get; set; } = "";
    public bool IsOpen { get; set; }

    public bool AcceptsCheckIn(DateTime utcNow) =>
        IsOpen && OpenedAt is not null && (CheckInUntil is null || utcNow < CheckInUntil);

    // Planned = chưa mở điểm danh, Open = đang nhận điểm danh, Ended = đã mở và đã kết thúc.
    public string State(DateTime utcNow) => OpenedAt is null ? "Planned" : AcceptsCheckIn(utcNow) ? "Open" : "Ended";
}
