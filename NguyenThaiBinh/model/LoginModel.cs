namespace NguyenThaiBinh.model;

public record LoginRequest(string Username, string Password);

public record VerifyOtpRequest(string Username, string Code);
