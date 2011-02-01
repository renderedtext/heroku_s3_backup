require 'fog'

class HerokuS3Backup
  def self.backup(options = {})
    begin
      puts "[#{Time.now}] heroku:backup started"
      
      # Set app
      app = if options[:name] == false
      elsif options[:name]
        options[:name] + "-"
      else
        ENV['APP_NAME'] + "-"
      end
      
      # Set bucket
      bucket = if options[:bucket]
        options[:bucket]
      else
        "#{app}-heroku-backups"
      end
      
      # Set path
      path = if options[:path]
        options[:path]
      else
        "db"
      end
      
      # Set timestamp
      timestamp = if options[:timestamp]
        options[:timestamp]
      else
        "%Y-%m-%d-%H%M%S"
      end
      
      name = "#{app}#{Time.now.strftime(timestamp)}.sql"

      db = ENV['DATABASE_URL'].match(/postgres:\/\/([^:]+):([^@]+)@([^\/]+)\/(.+)/)
      system "PGPASSWORD=#{db[2]} pg_dump -Fc -i --username=#{db[1]} --host=#{db[3]} #{db[4]} > tmp/#{name}"

      puts "gzipping sql file..."
      `gzip tmp/#{name}`

      backup_path = "tmp/#{name}.gz"

      s3 = Fog::Storage.new(
        :provider => 'AWS',
        :aws_access_key_id => ENV['S3_KEY'],
        :aws_secret_access_key => ENV['S3_SECRET']
      )
      s3.get_service
    
      begin
        s3.get_bucket(bucket)
        directory = s3.directories.get(bucket)
      rescue Excon::Errors::NotFound
        directory = s3.directories.create(:key => bucket)
        s3.get_bucket(bucket)
      end

      directory.files.create(:key => "#{path}/#{name}.gz", :body => open(backup_path))
      system "rm #{backup_path}"
      puts "[#{Time.now}] heroku:backup complete"
      
    rescue Exception => e
      if ENV['HOPTOAD_KEY']
        require 'toadhopper'
        Toadhopper(ENV['HOPTOAD_KEY']).post!(e)
      else
        puts "S3 backup error: #{e}"
      end
    end
  end
end
