import Foundation
import WMFData

@objc(WMFRandomArticleFetcher)
public final class RandomArticleFetcher: Fetcher {
    @objc public func fetchRandomArticle(withSiteURL siteURL: URL, completion: @escaping (Error?, URL?, ArticleSummary?) -> Void) {
        if NITCWikiFeatureFlags.current.isNITCWiki {
            Task {
                do {
                    let project = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil))
                    let randomArticles = try await WMFRandomDataController.shared.fetchRandomArticles(project: project)
                    guard let firstArticle = randomArticles.first else {
                        DispatchQueue.main.async {
                            completion(Fetcher.unexpectedResponseError, nil, nil)
                        }
                        return
                    }
                    let title = firstArticle.title
                    let articleURL = siteURL.wmf_URL(withTitle: title)
                    var thumbnail: ArticleSummaryImage? = nil
                    if let thumb = firstArticle.thumbnail, let source = thumb.source, let width = thumb.width, let height = thumb.height {
                        thumbnail = ArticleSummaryImage(source: source, width: width, height: height)
                    }
                    let desktopURLs = ArticleSummaryURLs(page: articleURL?.absoluteString)
                    let summary = ArticleSummary(id: Int64(firstArticle.pageid), wikidataID: nil, revision: nil, timestamp: nil, index: nil, namespace: ArticleSummary.Namespace(id: 0, text: nil), title: title, displayTitle: firstArticle.displayTitle ?? title, articleDescription: firstArticle.description, extract: firstArticle.extract, extractHTML: nil, thumbnail: thumbnail, original: nil, coordinates: nil, languageVariantCode: nil, contentURLs: ArticleSummaryContentURLs(desktop: desktopURLs, mobile: nil))
                    DispatchQueue.main.async {
                        completion(nil, articleURL, summary)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(error, nil, nil)
                    }
                }
            }
            return
        }

        let pathComponents = ["page", "random", "summary"]
        guard let taskURL = configuration.feedContentAPIURLForURL(siteURL, appending: pathComponents) else {
            completion(Fetcher.invalidParametersError, nil, nil)
            return
        }
        session.jsonDecodableTask(with: taskURL) { (summary: ArticleSummary?, response, error) in
            if let error = error {
                completion(error, nil, nil)
                return
            }
            guard var articleURL = summary?.articleURL else {
                completion(Fetcher.unexpectedResponseError, nil, nil)
                return
            }
            // Temporary shim until ArticleSummary propagates language variants.
            // Ensures Random cards display content when variants are turned on.
            articleURL.wmf_languageVariantCode = siteURL.wmf_languageVariantCode
            completion(nil, articleURL, summary)
        }
    }
}
