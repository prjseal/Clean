//------------------------------------------------------------------------------
// <auto-generated>
//   This code was generated by a tool.
//
//    Umbraco.ModelsBuilder.Embedded v10.4.0+daff988
//
//   Changes to this file will be lost if the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

using System;
using System.Linq.Expressions;
using Umbraco.Cms.Core.Models.PublishedContent;
using Umbraco.Cms.Core.PublishedCache;
using Umbraco.Cms.Infrastructure.ModelsBuilder;
using Umbraco.Cms.Core;
using Umbraco.Extensions;

namespace Umbraco.Cms.Web.Common.PublishedModels
{
	// Mixin Content Type with alias "articleControls"
	/// <summary>Article Controls</summary>
	public partial interface IArticleControls : IPublishedContent
	{
		/// <summary>Article Date</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		global::System.DateTime ArticleDate { get; }

		/// <summary>Author</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[global::System.Diagnostics.CodeAnalysis.MaybeNull]
		string Author { get; }

		/// <summary>Categories</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[global::System.Diagnostics.CodeAnalysis.MaybeNull]
		global::System.Collections.Generic.List<global::Umbraco.Cms.Core.Models.PublishedContent.IPublishedContent> Categories { get; }
	}

	/// <summary>Article Controls</summary>
	[PublishedModel("articleControls")]
	public partial class ArticleControls : PublishedContentModel, IArticleControls
	{
		// helpers
#pragma warning disable 0109 // new is redundant
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		public new const string ModelTypeAlias = "articleControls";
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		public new const PublishedItemType ModelItemType = PublishedItemType.Content;
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[return: global::System.Diagnostics.CodeAnalysis.MaybeNull]
		public new static IPublishedContentType GetModelContentType(IPublishedSnapshotAccessor publishedSnapshotAccessor)
			=> PublishedModelUtility.GetModelContentType(publishedSnapshotAccessor, ModelItemType, ModelTypeAlias);
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[return: global::System.Diagnostics.CodeAnalysis.MaybeNull]
		public static IPublishedPropertyType GetModelPropertyType<TValue>(IPublishedSnapshotAccessor publishedSnapshotAccessor, Expression<Func<ArticleControls, TValue>> selector)
			=> PublishedModelUtility.GetModelPropertyType(GetModelContentType(publishedSnapshotAccessor), selector);
#pragma warning restore 0109

		private IPublishedValueFallback _publishedValueFallback;

		// ctor
		public ArticleControls(IPublishedContent content, IPublishedValueFallback publishedValueFallback)
			: base(content, publishedValueFallback)
		{
			_publishedValueFallback = publishedValueFallback;
		}

		// properties

		///<summary>
		/// Article Date: Enter the date for the article
		///</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[ImplementPropertyType("articleDate")]
		public virtual global::System.DateTime ArticleDate => GetArticleDate(this, _publishedValueFallback);

		/// <summary>Static getter for Article Date</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		public static global::System.DateTime GetArticleDate(IArticleControls that, IPublishedValueFallback publishedValueFallback) => that.Value<global::System.DateTime>(publishedValueFallback, "articleDate");

		///<summary>
		/// Author: Choose the author for this article
		///</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[global::System.Diagnostics.CodeAnalysis.MaybeNull]
		[ImplementPropertyType("author")]
		public virtual string Author => GetAuthor(this, _publishedValueFallback);

		/// <summary>Static getter for Author</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[return: global::System.Diagnostics.CodeAnalysis.MaybeNull]
		public static string GetAuthor(IArticleControls that, IPublishedValueFallback publishedValueFallback) => that.Value<string>(publishedValueFallback, "author");

		///<summary>
		/// Categories: Choose the categories for this article
		///</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[global::System.Diagnostics.CodeAnalysis.MaybeNull]
		[ImplementPropertyType("categories")]
		public virtual global::System.Collections.Generic.List<global::Umbraco.Cms.Core.Models.PublishedContent.IPublishedContent> Categories => GetCategories(this, _publishedValueFallback);

		/// <summary>Static getter for Categories</summary>
		[global::System.CodeDom.Compiler.GeneratedCodeAttribute("Umbraco.ModelsBuilder.Embedded", "10.4.0+daff988")]
		[return: global::System.Diagnostics.CodeAnalysis.MaybeNull]
		public static global::System.Collections.Generic.List<global::Umbraco.Cms.Core.Models.PublishedContent.IPublishedContent> GetCategories(IArticleControls that, IPublishedValueFallback publishedValueFallback) => that.Value<global::System.Collections.Generic.List<global::Umbraco.Cms.Core.Models.PublishedContent.IPublishedContent>>(publishedValueFallback, "categories");
	}
}
