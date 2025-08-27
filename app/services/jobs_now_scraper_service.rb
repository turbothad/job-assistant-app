class JobsNowScraperService
  include HTTParty
  base_uri 'https://www.jobs.now'

  def initialize(keywords: [], location: nil, category: nil)
    @keywords = keywords
    @location = location
    @category = category
  end

  def call
    scrape_jobs
  end

  private

  def scrape_jobs
    jobs = []
    
    # First, get the sitemap to find all job URLs
    job_urls = fetch_job_urls_from_sitemap
    
    # Limit to first 5 for testing
    job_urls.first(5).each_with_index do |job_url, index|
      puts "Processing job #{index + 1}/5: #{job_url}"
      job_data = scrape_individual_job(job_url)
      
      if job_data
        puts "  Successfully extracted job data: #{job_data[:title]}"
        if matches_criteria?(job_data)
          puts "  ✓ Job matches criteria, adding to results"
          jobs << job_data
        else
          puts "  ✗ Job doesn't match criteria"
        end
      else
        puts "  ✗ Failed to extract job data"
      end
    end
    
    jobs
  end

  def fetch_job_urls_from_sitemap
    response = self.class.get('/sitemap-jobs-1.xml')
    return [] unless response.success?
    
    # Parse XML and extract job URLs
    doc = Nokogiri::XML(response.body)
    
    # Extract all <loc> elements from the XML
    urls = doc.xpath('//xmlns:url/xmlns:loc', 'xmlns' => 'http://www.sitemaps.org/schemas/sitemap/0.9').map(&:text)
    
    # If namespace approach doesn't work, try without namespace
    if urls.empty?
      # Remove namespace for simpler parsing
      body_without_namespace = response.body.gsub(/ xmlns="[^"]*"/, '')
      doc = Nokogiri::XML(body_without_namespace)
      urls = doc.xpath('//url/loc').map(&:text)
    end
    
    # Filter for job URLs and ensure they're complete URLs
    job_urls = urls.select { |url| url.include?('/jobs/') }
    
    # Debug: print first few URLs to see what we're getting
    puts "Found #{job_urls.length} job URLs. First 5:" if job_urls.any?
    job_urls.first(5).each { |url| puts "  #{url}" } if job_urls.any?
    
    job_urls
  end

  def scrape_individual_job(job_url)
    puts "    Fetching full URL: #{job_url}"
    
    # Use HTTParty to fetch the full URL directly
    response = HTTParty.get(job_url, {
      headers: {
        'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      }
    })
    
    unless response.success?
      puts "    ✗ HTTP request failed: #{response.code}"
      return nil
    end
    
    puts "    ✓ Successfully fetched job page"
    doc = Nokogiri::HTML(response.body)
    
    job_data = extract_job_data(doc, job_url)
    if job_data
      puts "    ✓ Successfully extracted job data"
    else
      puts "    ✗ Failed to extract job data from HTML"
    end
    
    job_data
  end

  def extract_job_data(doc, job_url)
    # Extract job information from the HTML
    title_element = doc.at_css('h1') || doc.at_css('title')
    title = title_element ? clean_text(title_element.text) : 'Unknown Position'
    
    # Try to extract company name from title or meta tags
    company = extract_company_name(doc, title)
    
    # Extract location - look for common location patterns
    location = extract_location(doc)
    
    # Extract salary if available
    salary_range = extract_salary(doc)
    
    # Extract job description
    description = extract_description(doc)
    
    # Extract remote work info
    remote = check_if_remote(doc, title, description)
    
    # Extract experience level
    experience_level = extract_experience_level(doc, title, description)
    
    # Extract posting date
    posted_at = extract_posted_date(doc)
    
    {
      title: title,
      company: company,
      location: location,
      salary_range: salary_range,
      description: description,
      remote: remote,
      experience_level: experience_level,
      posted_at: posted_at,
      job_url: job_url,
      source: 'jobs.now'
    }
  end

  def extract_company_name(doc, title)
    # Try multiple strategies to find company name
    
    # Strategy 1: Look for "at Company" in title
    if title.match(/ at (.+?)( - | \|)/i)
      return $1.strip
    end
    
    # Strategy 2: Look for meta tags
    og_title = doc.at_css('meta[property="og:title"]')
    if og_title && og_title['content'].match(/ at (.+)/i)
      return $1.strip
    end
    
    # Strategy 3: Look for company name in structured data
    company_element = doc.at_css('[data-company], .company-name, .employer')
    return clean_text(company_element.text) if company_element
    
    'Unknown Company'
  end

  def extract_location(doc)
    # Look for location indicators in various places
    location_selectors = [
      '[data-location]',
      '.location',
      '.job-location',
      'span:contains("Location")',
      'div:contains("Location")'
    ]
    
    location_selectors.each do |selector|
      element = doc.at_css(selector)
      next unless element
      
      text = clean_text(element.text)
      next if text.empty?
      
      # Look for location patterns (City, State or Remote)
      if text.match(/([A-Za-z\s]+,\s*[A-Z]{2}|Remote|USA)/i)
        return text
      end
    end
    
    # Fallback: look in the page text for location patterns
    page_text = doc.text
    if match = page_text.match(/(?:Location|Based in|Office in).*?([A-Za-z\s]+,\s*[A-Z]{2})/i)
      return match[1]
    end
    
    nil
  end

  def extract_salary(doc)
    # Look for salary information
    salary_patterns = [
      /\$[\d,]+(?:\.\d{2})?\s*(?:-|to)\s*\$[\d,]+(?:\.\d{2})?/i,
      /\$[\d,]+(?:\.\d{2})?(?:\s*\/\s*year)?/i,
      /[\d,]+k\s*(?:-|to)\s*[\d,]+k/i
    ]
    
    page_text = doc.text
    salary_patterns.each do |pattern|
      if match = page_text.match(pattern)
        return match[0]
      end
    end
    
    nil
  end

  def extract_description(doc)
    # Try to find job description in common locations
    description_selectors = [
      '.job-description',
      '.description',
      '[data-description]',
      'div:contains("Job Description")',
      'div:contains("Description")'
    ]
    
    description_selectors.each do |selector|
      element = doc.at_css(selector)
      if element
        text = clean_text(element.text)
        return text if text.length > 100 # Ensure it's substantial content
      end
    end
    
    # Fallback: get the largest text block
    text_blocks = doc.css('p, div').map { |el| clean_text(el.text) }
    longest_block = text_blocks.max_by(&:length)
    
    longest_block if longest_block && longest_block.length > 100
  end

  def check_if_remote(doc, title, description)
    text_to_check = "#{title} #{description}".downcase
    
    remote_indicators = [
      'remote', 'work from home', 'wfh', 'distributed', 'virtual',
      'telecommute', 'home office', 'anywhere'
    ]
    
    remote_indicators.any? { |indicator| text_to_check.include?(indicator) }
  end

  def extract_experience_level(doc, title, description)
    text_to_check = "#{title} #{description}".downcase
    
    if text_to_check.match(/senior|sr\.|lead|principal|staff|architect/i)
      'Senior'
    elsif text_to_check.match(/junior|jr\.|entry|associate|intern/i)
      'Junior'
    elsif text_to_check.match(/manager|director|head of|vp|vice president/i)
      'Management'
    else
      'Mid-level'
    end
  end

  def extract_posted_date(doc)
    # Look for posting date
    date_selectors = [
      '[data-posted]',
      '.posted-date',
      '.job-date',
      'time[datetime]'
    ]
    
    date_selectors.each do |selector|
      element = doc.at_css(selector)
      if element
        date_text = element['datetime'] || element.text
        begin
          return Date.parse(date_text)
        rescue
          next
        end
      end
    end
    
    # Look for "X days ago" pattern
    page_text = doc.text
    if match = page_text.match(/(\d+)\s+days?\s+ago/i)
      return match[1].to_i.days.ago.to_date
    end
    
    # Default to today if we can't find a date
    Date.current
  end

  def matches_criteria?(job_data)
    return true if @keywords.empty? && @location.nil? && @category.nil?
    
    # Check keywords
    if @keywords.any?
      text_to_search = "#{job_data[:title]} #{job_data[:description]} #{job_data[:company]}".downcase
      keyword_match = @keywords.any? { |keyword| text_to_search.include?(keyword.downcase) }
      return false unless keyword_match
    end
    
    # Check location
    if @location
      return false unless job_data[:location]&.downcase&.include?(@location.downcase)
    end
    
    # Check category (would need to implement category mapping)
    if @category
      # This would require mapping job titles/descriptions to categories
      # For now, we'll skip this check
    end
    
    true
  end

  def clean_text(text)
    return '' unless text
    
    text.strip
        .gsub(/\s+/, ' ')
        .gsub(/[^\x00-\x7F]/, '') # Remove non-ASCII characters
        .strip
  end
end
