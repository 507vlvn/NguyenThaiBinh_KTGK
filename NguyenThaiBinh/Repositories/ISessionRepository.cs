using NguyenThaiBinh.model;

namespace NguyenThaiBinh.Repositories;

public interface ISessionRepository
{
    IQueryable<ClassSession> Sessions();
    IQueryable<Attendance> Attendances();
    void AddSession(ClassSession session);
    void RemoveSession(ClassSession session);
    void AddAttendance(Attendance attendance);
    void RemoveAttendance(Attendance attendance);
    Task<bool> SaveAsync();
}
