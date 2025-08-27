namespace :jobs do
  desc "Scrape jobs from Jobs.Now"
  task scrape: :environment do
    puts "Starting Jobs.Now scraper..."
    
    # Example usage with keywords
    keywords = ENV['KEYWORDS']&.split(',') || ['ruby', 'rails', 'software engineer']
    location = ENV['LOCATION'] # e.g., "San Francisco, CA"
    
    scraper = JobsNowScraperService.new(
      keywords: keywords,
      location: location
    )
    
    jobs = scraper.call
    
    puts "Found #{jobs.length} matching jobs:"
    puts "=" * 50
    
    jobs.each_with_index do |job, index|
      puts "\n#{index + 1}. #{job[:title]}"
      puts "   Company: #{job[:company]}"
      puts "   Location: #{job[:location]}"
      puts "   Salary: #{job[:salary_range]}" if job[:salary_range]
      puts "   Remote: #{job[:remote] ? 'Yes' : 'No'}"
      puts "   Experience: #{job[:experience_level]}"
      puts "   Posted: #{job[:posted_at]}"
      puts "   URL: #{job[:job_url]}"
      puts "   Description: #{job[:description][0..200]}..." if job[:description]
      puts "-" * 40
    end
    
    # Optionally save to database
    if ENV['SAVE_TO_DB'] == 'true'
      puts "\nSaving jobs to database..."
      
      jobs.each do |job_data|
        job = JobListing.find_or_initialize_by(job_url: job_data[:job_url])
        job.assign_attributes(job_data.except(:source))
        
        if job.save
          puts "✓ Saved: #{job.title}"
        else
          puts "✗ Failed to save: #{job.title} - #{job.errors.full_messages.join(', ')}"
        end
      end
    end
    
    puts "\n🎉 Scraping completed!"
  end
  
  desc "Test scraper with a single job"
  task test: :environment do
    puts "Testing Jobs.Now scraper with a single job..."
    
    scraper = JobsNowScraperService.new
    
    # Test with a specific job URL from the sitemap we saw earlier
    test_url = "https://www.jobs.now/jobs/157862534-compensation-analyst-iii-ref-r-01326694"
    
    # Extract job ID and test individual job scraping
    job_id = test_url.match(/\/jobs\/(\d+)/)[1]
    
    response = HTTParty.get(test_url)
    if response.success?
      doc = Nokogiri::HTML(response.body)
      job_data = scraper.send(:extract_job_data, doc, test_url)
      
      puts "Test job data:"
      puts JSON.pretty_generate(job_data.transform_keys(&:to_s))
    else
      puts "Failed to fetch test job: #{response.code}"
    end
  end
end
