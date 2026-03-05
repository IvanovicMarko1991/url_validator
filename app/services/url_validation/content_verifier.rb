module UrlValidation
  class ContentVerifier
    def self.extract_title(html)
      return nil if html.blank?
      html.match(/<title[^>]*>(.*?)<\/title>/im)&.captures&.first&.strip
    end

    def self.title_matches_job?(page_title, job_title)
      return nil if page_title.blank? || job_title.blank?
      normalize(page_title).include?(normalize(job_title))
    end

    def self.normalize(text)
      text.to_s.downcase.gsub(/\s+/, " ").strip
    end
  end
end
