using NguyenThaiBinh.model;

namespace NguyenThaiBinh.Repositories;

public interface ILeaveRequestRepository
{
    IQueryable<LeaveRequest> LeaveRequests();
    void Add(LeaveRequest leaveRequest);
    Task<bool> SaveAsync();
}
