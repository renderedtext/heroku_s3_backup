require 'aws/s3'

class HerokuS3Backup
  def self.backup
    begin
      puts "[#{Time.now}] heroku:backup started"
      name = "#{ENV['APP_NAME']}-#{Time.now.strftime('%Y-%m-%d-%H%M%S')}.dump"
      s3 = AWS::S3::Base.establish_connection!(
        :access_key_id     => ENV['s3_access_key_id'],
        :secret_access_key => ENV['s3_secret_access_key']
      )
      bucket_name = if ENV['backup_bucket']
        ENV['backup_bucket']
      else
        "#{ENV['APP_NAME']}-heroku-backups"
      end
      
      bucket = begin
        AWS::S3::Bucket.find(bucket_name)
      rescue AWS::S3::NoSuchBucket
        AWS::S3::Bucket.create(bucket_name)
      end
      
      raise "Amazon bucket error" unless bucket
      
      db = ENV['DATABASE_URL'].match(/postgres:\/\/([^:]+):([^@]+)@([^\/]+)\/(.+)/)
      system "PGPASSWORD=#{db[2]} pg_dump -Fc -i --username=#{db[1]} --host=#{db[3]} #{db[4]} > tmp/#{name}"

      AWS::S3::S3Object.store("backups/" + name, open("tmp/#{name}"), bucket_name)
      system "rm tmp/#{name}"
      puts "[#{Time.now}] heroku:backup complete"
      # rescue Exception => e
      #   require 'toadhopper'
      #   Toadhopper(ENV['hoptoad_key']).post!(e)
    end
  end
end
