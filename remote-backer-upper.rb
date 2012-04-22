#!/usr/bin/env ruby
# remote backer upper
# version 1.0
# by dale karp
# http://dale.io || @daliuss

require 'yaml'
require 'net/scp'

# generate name to be used for backup folder/tar
bkup_name = Time.now.strftime("%Y-%m-%d_%H-%M_backup")

# open & read config file
begin
  File.open("config.yml") { |file| @config = YAML.load(file) }
rescue Exception => e
  raise "Cannot find config.yml"
end
options = { # used in Net::SSH.start
  :password => @config["password"]
}

# ensure destination directory exists
if File.directory?(@config["destination_folder"]) == false
  raise "#{@config["destination_folder"]} is not a folder."
end

# connect to remote host
begin
  Net::SSH.start(@config["host"], @config["user_name"], options) do |ssh|
    # create backup folder
    ssh.exec!("mkdir #{bkup_name}")

    # if any folders to back up exist in config, create 'files' folder and copy
    if @config["folders"].nil? == false
      ssh.exec!("mkdir #{bkup_name}/files")
      @config["folders"].each do |folder|
        ssh.exec!("cp -a #{folder} #{bkup_name}/files")
      end
    end

    # if any databases to back up exist in config, create 'db' folder, backup dbs and copy dumps
    if @config["databases"].nil? == false
      ssh.exec!("mkdir #{bkup_name}/db")
      @config["databases"].each do |db|
        ssh.exec!("mysqldump -h localhost -u #{db['user_name']} -p#{db['password']} #{db['db_name']} > #{bkup_name}/db/#{db['db_name']}.sql")
      end
    end

    # creating a tar of backup folder
    ssh.exec!("tar -cpzf #{bkup_name}.tar.gz #{bkup_name}/")

    # copy folder back to localhost
    ssh.scp.download!("#{bkup_name}.tar.gz", @config["destination_folder"])

    # clean up files and folders on remote host
    ssh.exec!("rm -r #{bkup_name} && rm #{bkup_name}.tar.gz") 
  end
rescue Exception => e
  raise "There was a problem connecting to the remote host: #{e}"
end