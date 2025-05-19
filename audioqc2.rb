require 'json'
require 'csv'
# require 'parallel'
load 'audioqc_methods.rb'
load_options('settings.csv')

targets = ARGV
file_inputs = []
qc_files = []
timestamp = Time.now.strftime('%Y-%m-%d_%H-%M-%S')

targets.each do |target|
  if File.directory?(target)
    targets = Dir["#{target}/**/*.{WAV,wav}"]
    targets.each {|file| file_inputs << file}
  elsif File.extname(target).downcase == '.wav'
    file_inputs << target
  end
end

if File.exist?($output_path_custom)
  output_csv_path = $output_path_custom
else
  output_csv_path = ENV['HOME'] + "/Desktop/"
end
output_csv_name = "audioqc-out_#{timestamp}.csv"
output_csv = "#{output_csv_path}/#{output_csv_name}"


file_inputs.each {|file| qc_files << QcTarget.new(file)}

qc_files.each do |file|
  begin
    file.media_info
    file.media_conch
    file.calculatehash
    file.probe
    file.phase
    file.generate_warnings
  rescue
    file.error_warning
  end
end

qc_files.each do |file|
  file.write_csv_line(output_csv)
end

#Parallel version
# #Calculate hash of audio stream
# hashes = Parallel.map(qc_files) {|file| file.calculatehash}

# hashes.each_with_index do |hash, index|
#   qc_files[index].store_hash(hash)
# end

# #Calculate FFprobe information of input files
# probe_data = Parallel.map(qc_files) {|file| file.probe}

# probe_data.each_with_index do |probe, index|
#   qc_files[index].store_probe(probe)
# end
#Calculate average phase
# phase_data = Parallel.map(qc_files, in_processes: 1) {|file| file.phase}

# phase_data.each_with_index do |phase, index|
#   qc_files[index].store_phase(phase)
# end