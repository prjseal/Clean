# Pages

[Feature Guide](clean-features.md) > Pages

Clean has nine page types with templates, plus the Home page. This page shows each one on the website and in the backoffice.

---

## Contents

- [What every page has](#what-every-page-has)
- [Home](#home)
- [Content pages (Features and About)](#content-pages-features-and-about)
- [Blog (Article List)](#blog-article-list)
- [Article](#article)
- [Authors (Author List)](#authors-author-list)
- [Author](#author)
- [Contact](#contact)
- [Search](#search)
- [Error](#error)
- [XML Sitemap](#xml-sitemap)
- [Which tabs each page type has](#which-tabs-each-page-type-has)

---

## What every page has

Each page type is built from a set of shared compositions, so most pages have the same tabs in the backoffice. The compositions are described in [Backoffice structure](clean-features-backoffice.md#compositions).

| Tab | Fields | What it does on the website |
|-----|--------|-----------------------------|
| **Content** | Content Rows | The [content blocks](clean-features-blocks.md) that make up the body of the page |
| **Hero** | Title, Subtitle, Main Image | The hero at the top of the page. If Title is empty, the page name is used. If Main Image is empty, a default background image is used |
| **SEO** | Meta Name, Meta Description, Meta Keywords, Is Indexable, Is Followable | The `<title>`, meta, Open Graph and Twitter tags, and the robots tag. See [SEO](clean-features-seo-and-navigation.md#seo) |
| **Visibility** | Hide From Top Navigation, Hide From Search, Hide From XML Sitemap | Keeps the page out of the main menu, listings and the sitemap. See [Visibility](clean-features-seo-and-navigation.md#visibility) |

The Hero tab looks the same on every page:

![The Hero tab](images/backoffice/content/02-home-about/hero.png)

---

## Home

The root of the site. It shows the three most recent blog articles, and it holds the footer's social links, which every page uses.

![The home page](images/frontend/home.png)

In the sample content, the home page has one block: a **Latest Articles** row pointing at the Blog page, showing 3 articles with no pagination.

![Home: Content tab](images/backoffice/content/01-home/content.png)

The **Footer** tab holds the social icon links shown at the bottom of every page. Each one is an Icon Link Row with an SVG icon and a link. See [Footer and social links](clean-features-seo-and-navigation.md#footer-and-social-links).

![Home: Footer tab](images/backoffice/content/01-home/footer.png)

<details>
<summary>More Home tabs (Hero, SEO)</summary>

![Home: Hero tab](images/backoffice/content/01-home/hero.png)

![Home: SEO tab](images/backoffice/content/01-home/seo.png)

</details>

Home has no Visibility tab: it is always in the navigation (as the first link) and always first in the sitemap.

Allowed child pages: Content, Contact, Article List, Search, Error, XML Sitemap and Author List.

---

## Content pages (Features and About)

**Document type:** Content

The general-purpose page. Its body is made entirely of content blocks, so it can hold any mix of text, images, videos, code and carousels. The sample content has two:

- **Features** demonstrates every content block. It is the best page to look at when you want to see what the blocks do.
- **About** is a simple page of rich text and an image.

| Features | About |
|----------|-------|
| ![The Features page](images/frontend/features.png) | ![The About page](images/frontend/about.png) |

The Features page's **Content** tab shows each block with a label that previews its content:

![Features: Content tab](images/backoffice/content/15-home-features/content.png)

<details>
<summary>More tabs (About: Content, Hero, SEO, Visibility)</summary>

![About: Content tab](images/backoffice/content/02-home-about/content.png)

![About: Hero tab](images/backoffice/content/02-home-about/hero.png)

![About: SEO tab](images/backoffice/content/02-home-about/seo.png)

![About: Visibility tab](images/backoffice/content/02-home-about/visibility.png)

</details>

---

## Blog (Article List)

**Document type:** Article List

The parent of all articles. The listing itself comes from a **Latest Articles** block on the page, which lists the visible articles under a chosen page, newest first by Article Date. On the Blog page it shows 5 articles at a time with pagination.

| Page 1 | Page 2 |
|--------|--------|
| ![The blog, page 1](images/frontend/blog.png) | ![The blog, page 2](images/frontend/blog-page-2.png) |

Pagination uses the `?page=` query string and the **Paging** dictionary items for its labels.

Article List shows its children in a collection, so the **Child items** view opens first in the backoffice, with a **Create Article** button:

![Blog: Child items](images/backoffice/content/05-home-blog/child-items.png)

The **Content** tab holds the Latest Articles block:

![Blog: Content tab](images/backoffice/content/05-home-blog/content.png)

<details>
<summary>More Blog tabs (Hero, SEO, Visibility)</summary>

![Blog: Hero tab](images/backoffice/content/05-home-blog/hero.png)

![Blog: SEO tab](images/backoffice/content/05-home-blog/seo.png)

![Blog: Visibility tab](images/backoffice/content/05-home-blog/visibility.png)

</details>

Allowed child pages: Article.

---

## Article

**Document type:** Article

A blog post. As well as the usual tabs, it has an **Article Details** tab. The hero shows the title, subtitle, "Posted by *author* on *date*" and a tag for each category, sorted by name.

![An article](images/frontend/article.png)

The **Article Details** tab:

| Field | Required | Notes |
|-------|----------|-------|
| Article Date | Yes | Date and time. Used for the byline and to sort article listings |
| Author | Yes | Picks one Author page. The picker opens at the Authors page |
| Categories | No | Picks any number of categories from the [Library](clean-features-backoffice.md#library-categories) |

![Article: Article Details tab](images/backoffice/content/06-home-blog-codegarden2026/article-details.png)

The body of the article is made of content blocks. The Codegarden 2026 article uses a Rich Text row followed by a Video row for each talk:

![Article: Content tab](images/backoffice/content/06-home-blog-codegarden2026/content.png)

<details>
<summary>More Article tabs (Hero, SEO, Visibility)</summary>

![Article: Hero tab](images/backoffice/content/06-home-blog-codegarden2026/hero.png)

![Article: SEO tab](images/backoffice/content/06-home-blog-codegarden2026/seo.png)

![Article: Visibility tab](images/backoffice/content/06-home-blog-codegarden2026/visibility.png)

</details>

<details>
<summary>The other sample articles</summary>

**YouTube Tutorials**

![YouTube Tutorials: Content tab](images/backoffice/content/12-home-blog-youtubetutorials/content.png)
![YouTube Tutorials: Article Details tab](images/backoffice/content/12-home-blog-youtubetutorials/article-details.png)

**Podcasts and Videos**

![Podcasts and Videos: Content tab](images/backoffice/content/10-home-blog-podcastsandvideos/content.png)
![Podcasts and Videos: Article Details tab](images/backoffice/content/10-home-blog-podcastsandvideos/article-details.png)

**Conferences**

![Conferences: Content tab](images/backoffice/content/08-home-blog-conferences/content.png)
![Conferences: Article Details tab](images/backoffice/content/08-home-blog-conferences/article-details.png)

**Meetups**

![Meetups: Content tab](images/backoffice/content/09-home-blog-meetups/content.png)
![Meetups: Article Details tab](images/backoffice/content/09-home-blog-meetups/article-details.png)

**Popular blogs**

![Popular blogs: Content tab](images/backoffice/content/11-home-blog-popularblogs/content.png)
![Popular blogs: Article Details tab](images/backoffice/content/11-home-blog-popularblogs/article-details.png)

**Community**

![Community: Content tab](images/backoffice/content/07-home-blog-community/content.png)
![Community: Article Details tab](images/backoffice/content/07-home-blog-community/article-details.png)

</details>

---

## Authors (Author List)

**Document type:** Author List

Lists the visible Author pages under it as cards, 10 per page with pagination. Each card shows the author's Main Image, their name, their **Meta Description** (from the SEO tab) as the summary, and a **Read More** link.

![The authors page](images/frontend/authors.png)

The Author List page does not render its Content Rows; the page body is always the list of authors.

The Author List page is also where the Author picker on articles looks for authors: the picker starts from the Home page and opens at the nearest Author List below it.

<details>
<summary>Authors tabs (Content, Hero, SEO, Visibility)</summary>

![Authors: Content tab](images/backoffice/content/03-home-authors/content.png)

![Authors: Hero tab](images/backoffice/content/03-home-authors/hero.png)

![Authors: SEO tab](images/backoffice/content/03-home-authors/seo.png)

![Authors: Visibility tab](images/backoffice/content/03-home-authors/visibility.png)

</details>

Allowed child pages: Author.

---

## Author

**Document type:** Author

A profile page for one author. The hero background comes from the parent Author List's Main Image, and the author's own **Main Image** is shown as a profile photo under the hero with their name as a caption. The rest of the page is content blocks.

![An author page](images/frontend/author.png)

![Author: Content tab](images/backoffice/content/04-home-authors-paulseal/content.png)

<details>
<summary>More Author tabs (Hero, SEO, Visibility)</summary>

![Author: Hero tab](images/backoffice/content/04-home-authors-paulseal/hero.png)

![Author: SEO tab](images/backoffice/content/04-home-authors-paulseal/seo.png)

![Author: Visibility tab](images/backoffice/content/04-home-authors-paulseal/visibility.png)

</details>

---

## Contact

**Document type:** Contact

A contact form with Name, Email Address and Message fields. All three are required, the email address must be valid, and the message can be up to 500 characters.

![The contact page](images/frontend/contact.png)

The **Content** tab holds the **Instruction Message** shown above the form:

![Contact: Content tab](images/backoffice/content/13-home-contact/content.png)

The **Result Messages** tab holds the **Success Message** and **Error Message**. After the form is sent, the page shows one of these in place of the form.

![Contact: Result Messages tab](images/backoffice/content/13-home-contact/result-messages.png)

<details>
<summary>More Contact tabs (Hero, SEO, Visibility)</summary>

![Contact: Hero tab](images/backoffice/content/13-home-contact/hero.png)

![Contact: SEO tab](images/backoffice/content/13-home-contact/seo.png)

![Contact: Visibility tab](images/backoffice/content/13-home-contact/visibility.png)

</details>

### How the form sends email

The form posts to `ContactSurfaceController` in `Clean.Core`. It sends one email through Umbraco's `IEmailSender`:

- **From** and **To** are both the `Umbraco:CMS:Global:Smtp:From` address
- **Subject** is `Enquiry from: <name> - <email>`
- **Body** is the message, as plain text

So the form needs Umbraco's SMTP settings. For example, in `appsettings.json`:

```json
{
  "Umbraco": {
    "CMS": {
      "Global": {
        "Smtp": {
          "From": "website@example.com",
          "Host": "smtp.example.com",
          "Port": 587,
          "Username": "website@example.com",
          "Password": "<password>"
        }
      }
    }
  }
}
```

Without SMTP settings, sending fails, the error is logged, and the visitor sees the Error Message.

The form labels and the Send button text are the **ContactForm** dictionary items. A headless version of the form is available at `POST /api/v1/contact/postContactForm`; see [Headless/API Implementation](clean-headless-api.md).

---

## Search

**Document type:** Search

A search box with paged results. Each result shows the page's title (or name), its subtitle, and for articles the author and date. The summary line ("We found 11 results when searching for umbraco") is the **Search.Results** dictionary item.

| Empty | With results |
|-------|--------------|
| ![The search page](images/frontend/search.png) | ![Search results](images/frontend/search-results.png) |

### How search works

- The search term is the `q` query string parameter, for example `/search/?q=umbraco`. The page number is `page`.
- Results come from `ISiteSearchService` in `Clean.Core`, which queries the published content index through Umbraco Search (`ISearcher`, with Examine as the default provider).
- The Error, Search and XML Sitemap page types are left out of the results by a filter in the query.
- Results are shown 10 per page.
- The same service powers the headless search endpoint, `GET /api/v1/search/getSearchResults`. See [Headless/API Implementation](clean-headless-api.md#search).

If results are missing, rebuild the published content index under **Settings > Search** in the backoffice.

The Search page has no Content tab. Its Hero tab holds Title, Subtitle and Main Image.

<details>
<summary>Search tabs (Hero, SEO, Visibility)</summary>

![Search: Hero tab](images/backoffice/content/16-home-search/hero.png)

![Search: SEO tab](images/backoffice/content/16-home-search/seo.png)

![Search: Visibility tab](images/backoffice/content/16-home-search/visibility.png)

</details>

---

## Error

**Document type:** Error

A "Page not found" page made of content blocks, with a link back to the home page.

![The error page](images/frontend/error.png)

The sample content does not set this page as the site's 404 page, so a missing URL shows Umbraco's built-in "Page Not Found" page. To use the Error page instead, add its key to `Error404Collection` in `appsettings.json`:

```json
{
  "Umbraco": {
    "CMS": {
      "Content": {
        "Error404Collection": [
          {
            "Culture": "default",
            "ContentKey": "abd58ca0-c700-47f3-b7ab-6672583572ce"
          }
        ]
      }
    }
  }
}
```

`abd58ca0-c700-47f3-b7ab-6672583572ce` is the key of the sample Error page. If you create your own, copy its key from the **Info** view in the backoffice.

<details>
<summary>Error tabs (Content, Hero, SEO, Visibility)</summary>

![Error: Content tab](images/backoffice/content/14-home-error/content.png)

![Error: Hero tab](images/backoffice/content/14-home-error/hero.png)

![Error: SEO tab](images/backoffice/content/14-home-error/seo.png)

![Error: Visibility tab](images/backoffice/content/14-home-error/visibility.png)

</details>

---

## XML Sitemap

**Document type:** XML Sitemap

Outputs the site's XML sitemap for search engines, at `/xmlsitemap/`. It has no visible page design. See [XML sitemap](clean-features-seo-and-navigation.md#xml-sitemap) for what it includes.

The page only has the Visibility fields. In the sample content all three are on, so the sitemap page itself is not in the menu, search results or the sitemap.

![XML Sitemap: Visibility fields](images/backoffice/content/17-home-xmlsitemap/content.png)

---

## Which tabs each page type has

| Page type | Content | Hero | Article Details | Result Messages | Footer | SEO | Visibility |
|-----------|:-------:|:----:|:---------------:|:---------------:|:------:|:---:|:----------:|
| Home | ✓ | ✓ | | | ✓ | ✓ | |
| Content | ✓ | ✓ | | | | ✓ | ✓ |
| Article List | ✓ | ✓ | | | | ✓ | ✓ |
| Article | ✓ | ✓ | ✓ | | | ✓ | ✓ |
| Author List | ✓ | ✓ | | | | ✓ | ✓ |
| Author | ✓ | ✓ | | | | ✓ | ✓ |
| Contact | ✓ (Instruction Message) | ✓ | | ✓ | | ✓ | ✓ |
| Search | | ✓ | | | | ✓ | ✓ |
| Error | ✓ | ✓ | | | | ✓ | ✓ |
| XML Sitemap | | | | | | | ✓ |

---

Next: [Content blocks](clean-features-blocks.md)
