using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NguyenThaiBinh.Migrations
{
    /// <inheritdoc />
    public partial class SessionScheduleAndOpening : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "CheckInUntil",
                table: "ClassSessions",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "OpenedAt",
                table: "ClassSessions",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CheckInUntil",
                table: "ClassSessions");

            migrationBuilder.DropColumn(
                name: "OpenedAt",
                table: "ClassSessions");
        }
    }
}
