using System;
using Umbraco.Cms.Core.Packaging;
using Umbraco.Cms.Infrastructure.Migrations;

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
            // This step used to create the element library items, which Umbraco could not
            // include in a package before 18.2. The package XML now carries them, so the step
            // does nothing, but it stays in the plan because sites that already ran it have
            // this state recorded and need it to exist to upgrade.
            To<NoopMigration>(new Guid("C3D4E5F6-A7B8-9012-CDEF-123456789ABC"));
        }
    }
}