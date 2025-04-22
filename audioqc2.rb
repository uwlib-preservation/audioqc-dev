require 'parallel'
require 'json'
require 'csv'
load 'audioqc_methods.rb'
load_options('settings.csv')

targets = ARGV
file_inputs = []
qc_files = []

targets.each do |target|
  if File.directory?(target)
    targets = Dir["#{target}/**/*.{WAV,wav}"]
    targets.each {|file| file_inputs << file}
  elsif File.extname(target).downcase == '.wav'
    file_inputs << target
  end
end



file_inputs.each {|file| qc_files << QcTarget.new(file)}


qc_files.each do |target|
  target.media_info
  target.media_conch
end

#Calculate hash of audio stream
hashes = Parallel.map(qc_files) {|file| file.calculatehash}

hashes.each_with_index do |hash, index|
  qc_files[index].store_hash(hash)
end

#Calculate FFprobe information of input files
probe_data = Parallel.map(qc_files) {|file| file.probe}

probe_data.each_with_index do |probe, index|
  qc_files[index].store_probe(probe)
end

#Calculate average phase
phase_data = Parallel.map(qc_files) {|file| file.phase}

phase_data.each_with_index do |phase, index|
  qc_files[index].store_phase(phase)
end

qc_files.each {|file| file.generate_warnings}

output_csv_path = "/home/weaveraj/Desktop/test.csv"


qc_files.each do |file|
  file.write_csv_line(output_csv_path)
  file.output
end