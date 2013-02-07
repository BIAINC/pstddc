require 'bundler'
Bundler.setup
Bundler.require

require 'erb'

task :default => :test

task :environment do
    ENV['RELEASE_ENV'] ||= 'ci'
    unless ['ci','release'].include?(ENV['RELEASE_ENV'])
      puts "Release environment is invalid #{ENV['RELEASE_ENV']}"
      exit 1
    end

    AWS.config(
      :access_key_id => ENV['ACCESS_KEY_ID'],
      :secret_access_key => ENV['SECRET_ACCESS_KEY'])

    ENV['VERSION'] = ENV['BUILD_NUMBER'] || `git rev-parse HEAD`.chomp
end

desc 'Run Unit Tests'
task :test do
  system('.\\test\\pester\\bin\\pester.bat .\\test\\unit')

  results = Nokogiri::XML::Document.parse(File.read('Test.xml'))
  results.remove_namespaces!

  test_failures = results.xpath('//test-case[@success="False"]').count
  unless test_failures.eql? 0
    puts "Exiting build, #{test_failures} test(s) failed"
    exit 1
  end

end


desc 'Release the build into the wild'
task :release => [:environment, :test] do
  
  s3 = AWS::S3.new
  bucket = s3.buckets['pstddc']

  base_key = "#{ENV['RELEASE_ENV']}/#{ENV['VERSION']}"

  install_template = ERB.new(File.read('Install.ps1.erb'))
  install_content = install_template.result(binding)

  puts "Uploading Build"
  bucket.objects["#{base_key}/Install.ps1"].write(install_content, :content_type => 'text/plain')
  bucket.objects["#{base_key}/TotalDiscovery.ps1"].write(Pathname.new('TotalDiscovery.ps1'), :content_type => 'text/plain')
  bucket.objects["#{base_key}/TotalDiscovery.psd1"].write(Pathname.new('TotalDiscovery.psd1'), :content_type => 'text/plain')

  if ENV['RELEASE_ENV'].eql?('release')
    puts "Releasing Installer"
    bucket.objects["/Install.ps1"].write(install_content, :content_type => 'application/text')
  end

end