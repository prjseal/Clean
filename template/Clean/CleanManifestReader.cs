using System.Collections.Generic;
using System.Linq;
using System.Text.Json.Nodes;
using System.Threading.Tasks;
using Umbraco.Cms.Core.Manifest;
using Umbraco.Cms.Infrastructure.Manifest;

namespace Clean
{
    internal class StarterKitManifestReader : IPackageManifestReader
    {
        public Task<IEnumerable<PackageManifest>> ReadPackageManifestsAsync()
        {
            var assembly = typeof(StarterKitManifestReader).Assembly;
            List<PackageManifest> manifest = [
                new PackageManifest
            {
                Extensions = [new JsonObject()],
                Name = "Clean",
                Version = assembly.GetName()?.Version?.ToString(3) ?? "5.0.0",
                AllowTelemetry = true
            }
            ];

            return Task.FromResult(manifest.AsEnumerable());
        }
    }
}