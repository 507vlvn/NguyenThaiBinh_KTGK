using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using NguyenThaiBinh.model;

namespace NguyenThaiBinh.Controllers;

public abstract class ApiControllerBase : ControllerBase
{
    protected int CurrentUserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
    protected bool IsAdmin => User.IsInRole(nameof(UserRole.Admin));
}
