require 'fog'

class HerokuS3Backup
  def self.backup
    begin
      puts "[#{Time.now}] heroku:backup started"
      name = "#{ENV['APP_NAME']}-#{Time.now.strftime('%Y-%m-%d-%H%M%S')}.sql"

      db = ENV['DATABASE_URL'].match(/postgres:\/\/([^:]+):([^@]+)@([^\/]+)\/(.+)/)
      system "PGPASSWORD=#{db[2]} pg_dump -Fc -i --username=#{db[1]} --host=#{db[3]} #{db[4]} > tmp/#{name}"

      puts "gzipping sql file..."
      `gzip tmp/#{name}`

      backup_path = "tmp/#{name}.gz"

      bucket_name = if ENV['backup_bucket']
        ENV['backup_bucket']
      else
        "#{ENV['APP_NAME']}-heroku-backups"
      end

      s3 = Fog::AWS::Storage.new(
        :aws_access_key_id => ENV['S3_KEY'],
        :aws_secret_access_key => ENV['S3_SECRET']
      )
      s3.get_service
    
      begin
        s3.get_bucket(bucket_name)
        directory = s3.directories.get(bucket_name)
      rescue Excon::Errors::NotFound
        directory = s3.directories.create(:key => bucket_name)
        s3.get_bucket(bucket_name)
      end

      directory.files.create(:key => "db/#{name}", :body => open(backup_path))
      system "rm #{backup_path}"
      puts "[#{Time.now}] heroku:backup complete"
      # rescue Exception => e
      #   require 'toadhopper'
      #   Toadhopper(ENV['hoptoad_key']).post!(e)
    end
  end
end
