using System;
using Umbraco.Cms.Core.Packaging;

namespace Clean.Migrations
{
    public class StarterKitPackageMigrationPlan : PackageMigrationPlan
    {
        public StarterKitPackageMigrationPlan()
            : base("Clean")
        {
        }

        protected override void DefinePlan()
        {
            To<ImportPackageXmlMigration>(new Guid("8643356A-0ACE-4361-B273-505ED098B4EA"));
            To<CreateElementLibraryMigration>(new Guid("C3D4E5F6-A7B8-9012-CDEF-123456789ABC"));
        }
    }
}