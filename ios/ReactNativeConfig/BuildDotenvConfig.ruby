#!/usr/bin/env ruby

require "json"

# pick a custom env file if set
if File.exists?("/tmp/envfile")
  custom_env = true
  file = File.read("/tmp/envfile").strip
else
  custom_env = false
  file = ".env"
end
package_json_path = File.join(Dir.pwd, "../../../package.json")

puts "Reading env from #{file}"
puts "Reading package.json from #{package_json_path}"

dotenv = begin
  # find that above node_modules/react-native-config/ios/
  raw = File.read(File.join(Dir.pwd, "../../../#{file}"))
  raw.split("\n").inject({}) do |h, line|
    key, val = line.split("=", 2)
    if line.strip.empty? or line.start_with?('#')
      h
    else
      key, val = line.split("=", 2)
      h.merge!(key => val)
    end
  end
rescue Errno::ENOENT
  puts("**************************")
  puts("*** Missing .env file ****")
  puts("**************************")
  {} # set dotenv as an empty hash
end

package_json = begin
  ret = Hash.new
  raw = File.read(package_json_path)
  raw = JSON.parse(raw).each { |k, v|
    if (v.kind_of? String) || (v.kind_of? Integer)
      ret.merge!(k => v)
    end
  }
  ret
rescue Errno::ENOENT
  puts("***************************************")
  puts("*** Can't find package.json file ! ****")
  puts("***************************************")
  puts("Looking at #{package_json_path}")
  {} # set dotenv as an empty hash
end

# add package json strings to macro
# package_json_objc = package_json.map { |k, v| %Q(@"#{k}":@"#{v}") }.join(",")

# create obj file that sets DOT_ENV as a NSDictionary
dotenv_objc = dotenv.map { |k, v| %Q(@"#{k}":@"#{v}") }.join(",")
template = <<EOF
  #define DOT_ENV @{ #{dotenv_objc} };
EOF

# write it so that ReactNativeConfig.m can return it
path = File.join(ENV["SYMROOT"], "GeneratedDotEnv.m")
File.open(path, "w") { |f| f.puts template }

# create header file with defines for the Info.plist preprocessor
package_json_info_plist_defines_objc = package_json.map { |k, v| %Q(#define __NPM_PACKAGE_#{k}  #{v}) }.join("\n")
rn_config_info_plist_defines_objc = dotenv.map { |k, v| %Q(#define __RN_CONFIG_#{k}  #{v}) }.join("\n")

# write it so the Info.plist preprocessor can access it
path = File.join(ENV["CONFIGURATION_BUILD_DIR"], "GeneratedInfoPlistDotEnv.h")
File.open(path, "w") { |f|
  f.puts package_json_info_plist_defines_objc
  f.puts rn_config_info_plist_defines_objc
}

if custom_env
  File.delete("/tmp/envfile")
end

puts "Wrote to #{path}"
