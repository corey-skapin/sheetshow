using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using SheetShow.Core.Entities;
using SheetShow.Infrastructure.Identity;

namespace SheetShow.Infrastructure.Persistence;

/// <summary>EF Core DbContext for SheetShow — extends IdentityDbContext for ASP.NET Core Identity.</summary>
public class ApplicationDbContext : IdentityDbContext<AppUser>
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options) { }

    public DbSet<Score> Scores => Set<Score>();
    public DbSet<Folder> Folders => Set<Folder>();
    public DbSet<ScoreTag> ScoreTags => Set<ScoreTag>();
    public DbSet<SetList> SetLists => Set<SetList>();
    public DbSet<SetListEntry> SetListEntries => Set<SetListEntry>();
    public DbSet<AnnotationLayer> AnnotationLayers => Set<AnnotationLayer>();
    public DbSet<SyncLog> SyncLogs => Set<SyncLog>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        // Global soft-delete query filters
        builder.Entity<Score>().HasQueryFilter(s => !s.IsDeleted);
        builder.Entity<Folder>().HasQueryFilter(f => !f.IsDeleted);
        builder.Entity<SetList>().HasQueryFilter(sl => !sl.IsDeleted);

        // Composite unique indexes
        builder.Entity<AnnotationLayer>()
            .HasIndex(a => new { a.ScoreId, a.PageNumber })
            .IsUnique();

        builder.Entity<SetListEntry>()
            .HasIndex(e => new { e.SetListId, e.OrderIndex })
            .IsUnique();

        builder.Entity<ScoreTag>()
            .HasIndex(t => new { t.UserId, t.Tag });

        builder.Entity<ScoreTag>()
            .HasKey(t => new { t.ScoreId, t.Tag });

        // Relationships
        builder.Entity<Score>()
            .HasMany(s => s.Tags)
            .WithOne()
            .HasForeignKey(t => t.ScoreId);

        builder.Entity<SetList>()
            .HasMany(sl => sl.Entries)
            .WithOne()
            .HasForeignKey(e => e.SetListId);

        builder.Entity<Folder>()
            .HasOne<Folder>()
            .WithMany()
            .HasForeignKey(f => f.ParentFolderId)
            .IsRequired(false);
    }
}
