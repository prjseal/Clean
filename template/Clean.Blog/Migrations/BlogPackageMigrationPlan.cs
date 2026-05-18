using Umbraco.Cms.Core.Packaging;

namespace Clean.Blog.Migrations;

public class BlogPackageMigrationPlan : PackageMigrationPlan
{
    public BlogPackageMigrationPlan()
        : base("Clean.Blog")
    {
    }

    protected override void DefinePlan()
    {
        To<ImportPackageXmlMigration>(new Guid("B1C9D0E1-2F34-4A56-9B78-C0D1E2F3A4B5"));
    }
}
