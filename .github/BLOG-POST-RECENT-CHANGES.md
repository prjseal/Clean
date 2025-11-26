# Clean Starter Kit: A Fresh Coat of Paint and Some Serious Spring Cleaning

If you've been following the **Clean Starter Kit** for Umbraco, you might have noticed we've been busy. Like, *really* busy. The kind of busy that involves reorganizing your entire garage and actually finding things afterwards.

## What's Clean, Anyway?

For those just joining us, **Clean** is a fully-featured starter kit for Umbraco CMS that gets you from zero to blogging in minutes. Think of it as your Umbraco kickstarter—complete with a modern blog theme, headless API capabilities, and all the content types you need to hit the ground running. It's like ordering a pizza with all your favorite toppings already on it. No assembly required (well, almost).

We support both **Umbraco 13 (.NET 8)** and the shiny new **Umbraco 17 LTS (.NET 10)**, so whether you're playing it safe or living on the edge, we've got you covered.

## The Big Changes: Documentation Gets a Makeover

Ever tried to find something in a drawer that's just filled with... stuff? That was our README. At nearly 300 lines, it had become the developer equivalent of that junk drawer in your kitchen—technically everything is there, but good luck finding it.

### What We Did

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

## Community Contributions: Joe Glombek Levels Up the Editor Experience

Here's where things get interesting. **Joe Glombek** (who clearly has an eye for UX) submitted PR #149 that improved something most developers overlook: the content editor experience.

### What Joe Did

Joe went through and updated descriptions across all our content types—articles, authors, categories, the whole family. But the real gem? He enhanced the BlockList labels and configurations.

If you've ever handed off an Umbraco site to a content editor and watched them squint at cryptic field names, you know why this matters. Joe made the admin interface clearer and more intuitive. Content editors rejoice!

**The Nitty-Gritty:**
- Updated 16+ content type configuration files
- Enhanced BlockList labels for better content editing
- Added new "Article List" view configurations
- Improved SEO and visibility control descriptions

It's the kind of contribution that might not make headlines, but makes everyone's day-to-day work just a little bit better. Thanks, Joe!

## The Four-Package Architecture (Or: Why We Have Four Packages)

Quick sidebar: Clean is actually four NuGet packages working together:

1. **Clean** - The full starter kit (use this for initial setup)
2. **Clean.Core** - The core library (switch to this after setup)
3. **Clean.Headless** - API and headless functionality
4. **Umbraco.Community.Templates.Clean** - The `dotnet new` template

Pro tip: After you get set up, switch from the `Clean` package to `Clean.Core`. This prevents your custom views and assets from getting steamrolled during updates. Learn from our mistakes so you don't have to make your own!

## What's Next?

We're actively looking for contributors (hint, hint). Whether you're into documentation, feature development, or just want to make things better for the next developer, we'd love to have you.

Current version is **7.0.0-rc4**, targeting Umbraco 17 LTS with .NET 10. We're in release candidate territory, which means things are stable but we're still polishing the edges.

## Try It Out

Getting started is ridiculously easy:

```bash
dotnet new install Umbraco.Community.Templates.Clean
dotnet new clean -n MyAwesomeBlog
```

Or if you prefer the traditional route, just install the `Clean` NuGet package into your Umbraco project.

Want to see it in action? There's a video walkthrough on YouTube, and the full documentation is now (finally) easy to navigate at [github.com/prjseal/Clean](https://github.com/prjseal/Clean).

## The Bottom Line

Building with Umbraco should be fun, not frustrating. Whether you're shipping a traditional blog or building a headless CMS for your Next.js app, Clean gets you there faster. And now with better docs and a more polished editor experience, it's easier than ever.

Questions? Issues? Want to contribute? Head over to the repo. We're friendly, we promise.

---

*Clean is maintained by Paul Seal (8x Umbraco MVP) with contributions from Phil Whittaker, Joe Glombek, and the community. It's MIT licensed, which means you can use it however you want. Go build something cool.*
