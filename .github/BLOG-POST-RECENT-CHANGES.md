# Clean Starter Kit v7: Ready for Umbraco 17 LTS

Today marks a milestone moment: **Umbraco 17 LTS** is officially here, and we're thrilled to announce that **Clean Starter Kit version 7** is launching right alongside it.

That's right—on the same day Umbraco releases their latest Long-Term Support version built on .NET 10, Clean is ready to help you hit the ground running. Whether you're starting a fresh project or exploring what Umbraco 17 can do, we've got you covered.

## What's Clean, Anyway?

For those just joining us, **Clean** is a fully-featured starter kit for Umbraco CMS that gets you from zero to blogging in minutes. Think of it as your Umbraco kickstarter—complete with a modern blog theme, headless API capabilities, and all the content types you need to start publishing immediately. It's like ordering a pizza with all your favorite toppings already on it. No assembly required (well, almost).

Version 7 brings full support for **Umbraco 17 LTS on .NET 10**, while we continue to support **Umbraco 13 (.NET 8)** for those on the previous LTS version. Whether you're upgrading or starting fresh, Clean makes it painless.

## The Journey: From Starter Kit to Platform

Before we dive into what's new, let's talk about how we got here. Clean didn't start as a sophisticated multi-version platform with automated everything. It began as a simple blog starter theme. What you're looking at now is the result of over 100 commits of deliberate evolution—transforming a good idea into an enterprise-grade development platform.

### The Automation Revolution

One of the biggest transformations has been in how we build and release Clean. We've gone from manual package creation (the "remember to do all these steps" approach) to **three fully automated GitHub Actions workflows** that handle everything:

**Pull Request Testing**: Every PR automatically builds test packages, installs them into fresh Umbraco instances, and uses Playwright to navigate the resulting sites—capturing screenshots for visual regression testing. It's like having a robot QA team that never sleeps.

**Automated Releases**: Tag a release, and the workflow kicks off. It extracts version numbers, updates documentation, builds packages in dependency order, publishes to NuGet, and even creates a PR to commit the version updates back to main. What used to take an hour now takes minutes, and it never forgets a step.

**Daily Dependency Updates**: The repository checks for Umbraco package updates every morning, validates builds succeed, and creates PRs with beautiful ASCII tables showing what changed. Because nobody wants to manually check for updates.

The real game-changer? **Custom NuGet source support**. Testing Clean against an Umbraco release candidate before it hits NuGet.org? Just add a line to your PR description. The workflow parses it and configures everything automatically. It's the kind of feature that makes you wonder how you ever lived without it.

### Solving Multi-Version Support (Without Losing Your Mind)

Here's a problem: Umbraco releases new major versions regularly. Do you support only the latest and alienate users on LTS versions? Or maintain separate branches for each version and double your workload?

We chose option three: **intelligent version mapping from a single branch**. The repository automatically maps Clean versions to Umbraco versions:
- Clean 4.x → Umbraco 13 (.NET 8)
- Clean 7.x → Umbraco 17 (.NET 10)

When you create a release, the automation reads the Clean version, knows which Umbraco version it targets, and updates the appropriate documentation sections. One codebase, multiple versions, zero manual coordination. It's version management done right.

### The Package Architecture Evolution

Early on, we hit a classic problem: users would install Clean, customize views and styles, then run `dotnet restore` and watch their changes get overwritten. Ouch.

The solution was splitting Clean into **four modular packages**:
1. **Clean** - The complete starter kit (use this for initial setup)
2. **Clean.Core** - Just the code, no views (switch here after setup)
3. **Clean.Headless** - API and headless functionality
4. **Umbraco.Community.Templates.Clean** - The `dotnet new` template

Now you can get all the starter content initially, then switch to Clean.Core to prevent updates from clobbering your work. It's documented, automated, and battle-tested.

### Documentation That Actually Helps

Remember that 290-line README that was basically a novel? We broke it into **11 specialized documentation files** in the `.github` folder:
- Contributing guidelines
- Release workflows
- Package creation deep-dives
- Version strategy
- Headless API documentation
- And more...

Each file focuses on one topic. Need to know how to contribute? There's a guide. Want to understand the release process? There's a guide. Wondering why we have a BlockList label workaround? (There's a story there—Umbraco bug #20801.) There's a guide for that too, complete with removal instructions for when Umbraco fixes it.

The README is now a hub—a jumping-off point that gets you started quickly and links to deeper resources when you need them.

### Quality Gates Everywhere

Modern Clean doesn't just build packages; it **validates** them. Every PR runs three complete installation tests using Playwright browser automation. The daily update workflow won't create a PR if builds fail—no more broken dependency updates making it through. We even extract and display build errors in pretty ASCII tables because life's too short for cryptic error messages.

And those BlockList labels that Glombek improved? We automatically fix an Umbraco packaging bug that strips them out. The fix runs during package creation, includes before/after console output so you can see exactly what changed, and is designed for easy removal when Umbraco ships the fix.

### What This Means for You

All this infrastructure means you're not just getting a starter kit—you're getting a **professionally maintained platform** with:
- Automated testing on every change
- Daily security and feature updates
- Multi-version support without branch hell
- Documentation that doesn't require a PhD to understand
- Quality gates that catch problems before they ship

## What's New in Version 7?

Beyond the Umbraco 17 compatibility, we've been busy making Clean better in every way. Here's what's changed:

### Documentation Gets a Makeover

Ever tried to find something in a drawer that's just filled with... stuff? That was our README. At nearly 300 lines, it had become the developer equivalent of that junk drawer in your kitchen—technically everything is there, but good luck finding it.

We went full Marie Kondo on our documentation:

**🗂️ Created a Centralized Documentation Hub** (PR #167)
We built `DOCUMENTATION.md`—your new single source of truth. It's organized into logical sections (Getting Started, Headless CMS, Contributing, etc.) and links to everything you need. Think of it as the table of contents your high school English teacher always insisted you needed.

**📝 Split Out the Technical Stuff** (PR #168)
We extracted the dense technical sections into dedicated guides:
- `HEADLESS-API.md` - Everything about using Clean as a headless CMS
- `PACKAGES.md` - Deep dive into our 4-package architecture

The result? Our README went from 290 lines down to a svelte 150. It now focuses on getting you started quickly instead of overwhelming you with every detail upfront.

**Better Developer Experience**
Finding information is now actually... pleasant? Novel concept, we know. Whether you're setting up your first Umbraco site or integrating with a Next.js frontend, the docs are now organized around what you're trying to *do*, not what we wanted to tell you.

### Community Contributions: Joe Glombek Levels Up the Editor Experience

Here's where things get interesting. **Joe Glombek** (who clearly has an eye for UX) submitted PR #149 that improved something most developers overlook: the content editor experience.

Joe went through and updated descriptions across all our content types—articles, authors, categories, the whole family. But the real gem? He enhanced the BlockList labels and configurations.

If you've ever handed off an Umbraco site to a content editor and watched them squint at cryptic field names, you know why this matters. Joe made the admin interface clearer and more intuitive. Content editors rejoice!

**The Nitty-Gritty:**
- Updated 16+ content type configuration files
- Enhanced BlockList labels for better content editing
- Added new "Article List" view configurations
- Improved SEO and visibility control descriptions

It's the kind of contribution that might not make headlines, but makes everyone's day-to-day work just a little bit better. Thanks, Joe!

## Quick Start: Which Package Do I Need?

Since Clean uses a modular architecture, here's the TL;DR:

**Starting from scratch?** Use the template:
```bash
dotnet new install Umbraco.Community.Templates.Clean
dotnet new clean -n MyBlog
```

**Adding to an existing Umbraco project?** Install the main package:
```bash
dotnet add package Clean --version 7.0.0
```

**Already using Clean?** Switch to Clean.Core after initial setup to prevent your customizations from being overwritten:
```bash
dotnet remove package Clean
dotnet add package Clean.Core
```

See the `PACKAGES.md` documentation for the complete migration guide.

## What's Next?

Version 7 is just the beginning. We're actively looking for contributors (hint, hint). Whether you're into documentation, feature development, or just want to make things better for the next developer, we'd love to have you.

**Clean 7.0.0** is available now, fully compatible with **Umbraco 17 LTS on .NET 10**. If you're on Umbraco 13, we've got version 4.x for you. We follow semantic versioning, so you'll always know which version of Clean works with your Umbraco installation.

## Ready to Dive In?

Clean 7.0.0 is available now on NuGet and ready for Umbraco 17 LTS. Whether you prefer the `dotnet new` template or adding packages to an existing project, you'll be up and running in minutes.

**Resources to get you started:**
- 📦 [NuGet Package](https://nuget.org/packages/Clean)
- 📚 [Complete Documentation](https://github.com/prjseal/Clean)
- 🎥 [Video Walkthrough](https://youtube.com) - See it in action
- 💬 [GitHub Discussions](https://github.com/prjseal/Clean/discussions) - Ask questions, share ideas

The documentation is now organized around what you're trying to accomplish—getting started, going headless, contributing, or diving into the technical details. Pick your path and go.

## The Bottom Line

Version 7 represents more than just Umbraco 17 compatibility—it's the culmination of a transformation from a simple starter kit into a professionally maintained, battle-tested platform. The automation infrastructure, quality gates, multi-version support, and comprehensive documentation mean you're building on solid ground.

Building with Umbraco should be fun, not frustrating. Whether you're shipping a traditional blog or building a headless CMS for your Next.js app, Clean gets you there faster. And with automated testing, daily updates, and a community of contributors making it better every day, you're in good hands.

Questions? Issues? Want to contribute? Head over to the [repo](https://github.com/prjseal/Clean). We're friendly, we promise.

---

*Clean is maintained by Paul Seal (8x Umbraco MVP) with contributions from Phil Whittaker, Joe Glombek, and the community. It's MIT licensed, which means you can use it however you want. Go build something cool.*
