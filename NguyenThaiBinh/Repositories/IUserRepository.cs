using NguyenThaiBinh.model;

namespace NguyenThaiBinh.Repositories;

public interface IUserRepository
{
    IQueryable<AppUser> Users();
    IQueryable<OtpCode> OtpCodes();
    void Add(AppUser user);
    void Remove(AppUser user);
    void AddOtp(OtpCode otp);
    Task<bool> SaveAsync();
}
