require 'parallel'
require 'json'
require 'csv'
load 'audioqc_methods.rb'

targets = ARGV
qc_files = []

targets.each {|target| qc_files << QcTarget.new(target)}

hashes = Parallel.map(qc_files) {|file| file.calculatehash}

hashes.each_with_index do |hash, index|
  qc_files[index].store_hash(hash)
end

probe_data = Parallel.map(qc_files) {|file| file.probe}

probe_data.each_with_index do |probe, index|
  qc_files[index].store_probe(probe)
end

phase_data = Parallel.map(qc_files) {|file| file.phase}

phase_data.each_with_index do |phase, index|
  qc_files[index].store_phase(phase)
end


output_csv_path = "/home/weaveraj/Desktop/test.csv"


qc_files.each do |file|
  file.write_csv_line(output_csv_path)
  file.output
end