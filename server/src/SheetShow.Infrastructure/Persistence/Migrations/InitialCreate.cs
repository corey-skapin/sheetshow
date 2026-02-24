using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SheetShow.Infrastructure.Persistence.Migrations
{
    /// <summary>Initial database migration — creates all SheetShow tables.</summary>
    /// <remarks>
    /// This migration was scaffolded manually as a placeholder.
    /// To regenerate from the actual DbContext, run:
    ///   dotnet ef migrations add InitialCreate
    ///     --project src/SheetShow.Infrastructure
    ///     --startup-project src/SheetShow.Api
    /// </remarks>
    public partial class InitialCreate : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Folders",
                columns: table => new
                {
                    Id = table.Column<Guid>(nullable: false),
                    UserId = table.Column<string>(nullable: false),
                    Name = table.Column<string>(maxLength: 255, nullable: false),
                    ParentFolderId = table.Column<Guid>(nullable: true),
                    Version = table.Column<int>(nullable: false, defaultValue: 1),
                    IsDeleted = table.Column<bool>(nullable: false, defaultValue: false),
                    DeletedAt = table.Column<DateTimeOffset>(nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Folders", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Folders_Folders_ParentFolderId",
                        column: x => x.ParentFolderId,
                        principalTable: "Folders",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "Scores",
                columns: table => new
                {
                    Id = table.Column<Guid>(nullable: false),
                    UserId = table.Column<string>(nullable: false),
                    Title = table.Column<string>(maxLength: 500, nullable: false),
                    Filename = table.Column<string>(maxLength: 255, nullable: false),
                    BlobPath = table.Column<string>(maxLength: 1024, nullable: false),
                    TotalPages = table.Column<int>(nullable: false),
                    FolderId = table.Column<Guid>(nullable: true),
                    Version = table.Column<int>(nullable: false, defaultValue: 1),
                    IsDeleted = table.Column<bool>(nullable: false, defaultValue: false),
                    DeletedAt = table.Column<DateTimeOffset>(nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Scores", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Scores_Folders_FolderId",
                        column: x => x.FolderId,
                        principalTable: "Folders",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateTable(
                name: "ScoreTags",
                columns: table => new
                {
                    ScoreId = table.Column<Guid>(nullable: false),
                    Tag = table.Column<string>(maxLength: 100, nullable: false),
                    UserId = table.Column<string>(nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ScoreTags", x => new { x.ScoreId, x.Tag });
                    table.ForeignKey(
                        name: "FK_ScoreTags_Scores_ScoreId",
                        column: x => x.ScoreId,
                        principalTable: "Scores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "SetLists",
                columns: table => new
                {
                    Id = table.Column<Guid>(nullable: false),
                    UserId = table.Column<string>(nullable: false),
                    Name = table.Column<string>(maxLength: 255, nullable: false),
                    Version = table.Column<int>(nullable: false, defaultValue: 1),
                    IsDeleted = table.Column<bool>(nullable: false, defaultValue: false),
                    DeletedAt = table.Column<DateTimeOffset>(nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SetLists", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "SetListEntries",
                columns: table => new
                {
                    Id = table.Column<Guid>(nullable: false),
                    SetListId = table.Column<Guid>(nullable: false),
                    ScoreId = table.Column<Guid>(nullable: false),
                    OrderIndex = table.Column<int>(nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SetListEntries", x => x.Id);
                    table.ForeignKey(
                        name: "FK_SetListEntries_SetLists_SetListId",
                        column: x => x.SetListId,
                        principalTable: "SetLists",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "AnnotationLayers",
                columns: table => new
                {
                    Id = table.Column<Guid>(nullable: false),
                    ScoreId = table.Column<Guid>(nullable: false),
                    UserId = table.Column<string>(nullable: false),
                    PageNumber = table.Column<int>(nullable: false),
                    StrokesJson = table.Column<string>(nullable: false, defaultValue: "[]"),
                    Version = table.Column<int>(nullable: false, defaultValue: 1),
                    UpdatedAt = table.Column<DateTimeOffset>(nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AnnotationLayers", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AnnotationLayers_Scores_ScoreId",
                        column: x => x.ScoreId,
                        principalTable: "Scores",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "SyncLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(nullable: false),
                    UserId = table.Column<string>(nullable: false),
                    DeviceId = table.Column<string>(nullable: false),
                    EntityType = table.Column<string>(maxLength: 50, nullable: false),
                    EntityId = table.Column<Guid>(nullable: false),
                    Operation = table.Column<string>(maxLength: 20, nullable: false),
                    PayloadJson = table.Column<string>(nullable: true),
                    AppliedAt = table.Column<DateTimeOffset>(nullable: false),
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SyncLogs", x => x.Id);
                });

            migrationBuilder.CreateIndex("IX_Scores_UserId_UpdatedAt", "Scores",
                new[] { "UserId", "UpdatedAt" });
            migrationBuilder.CreateIndex("IX_SyncLogs_UserId_AppliedAt", "SyncLogs",
                new[] { "UserId", "AppliedAt" });
            migrationBuilder.CreateIndex("IX_ScoreTags_UserId_Tag", "ScoreTags",
                new[] { "UserId", "Tag" });
            migrationBuilder.CreateIndex("IX_AnnotationLayers_ScoreId_PageNumber",
                "AnnotationLayers", new[] { "ScoreId", "PageNumber" }, unique: true);
            migrationBuilder.CreateIndex("IX_SetListEntries_SetListId_OrderIndex",
                "SetListEntries", new[] { "SetListId", "OrderIndex" }, unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable("AnnotationLayers");
            migrationBuilder.DropTable("SyncLogs");
            migrationBuilder.DropTable("SetListEntries");
            migrationBuilder.DropTable("SetLists");
            migrationBuilder.DropTable("ScoreTags");
            migrationBuilder.DropTable("Scores");
            migrationBuilder.DropTable("Folders");
        }
    }
}
