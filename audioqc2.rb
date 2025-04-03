require 'parallel'
require 'json'

targets = ARGV
qc_files = []

class QcTarget
  def initialize(value)
    @input_path = value
    @warnings = []
    @hash = ''
  end

  def calculatehash
    @md5 = `ffmpeg -nostdin -i #{@input_path} -c copy -f md5 -`
  end

  def probe
    channel_one_vol = []
    channel_two_vol = []
    ffprobe_command = "ffprobe -print_format json -threads auto -show_entries frame_tags=lavfi.astats.Overall.Number_of_samples,lavfi.astats.Overall.Peak_level,lavfi.astats.Overall.Max_difference,lavfi.astats.1.Peak_level,lavfi.astats.2.Peak_level,lavfi.astats.1.Peak_level,lavfi.astats.Overall.Mean_difference,lavfi.astats.Overall.Peak_level,lavfi.r128.I -f lavfi -i \"amovie='#{@input_path}'" + ',astats=reset=1:metadata=1,ebur128=metadata=1"'
    ffprobe_command.gsub!(':','\:')
    ffprobe_out = JSON.parse(`#{ffprobe_command}`)
    ffprobe_out['frames'].each do |frame|
    if frame['tags']['lavfi.astats.1.Peak_level'] == '-inf' || frame['tags']['lavfi.astats.2.Peak_level'] == '-inf'
      next
    else
      channel_one_vol << frame['tags']['lavfi.astats.1.Peak_level'].to_f
      channel_two_vol << frame['tags']['lavfi.astats.2.Peak_level'].to_f
    end
  end
  @channel_one_max = channel_one_vol.max
  @channel_two_max = channel_two_vol.max
  output = [@channel_one_max, @channel_two_max]
  end

  def phase
    channel_dif = (@channel_one_max - @channel_two_max).abs.to_s
    if@channel_two_max < @channel_one_max
      volume_command = ' -filter_complex "[0:a]channelsplit[a][b],[b]volume=volume=' + channel_dif + 'dB:precision=fixed[c],[a][c]amerge[out1]" -map [out1] '
    else
      volume_command = ' -filter_complex "[0:a]channelsplit[a][b],[a]volume=volume=' + channel_dif + 'dB:precision=fixed[c],[c][b]amerge[out1]" -map [out1] '
    end
    ffprobe_command = 'ffmpeg -i ' + @input_path + volume_command + ' -f wav - | ffprobe -print_format json -threads auto -show_entries frame_tags=lavfi.aphasemeter.phase -f lavfi -i "amovie=' + "'" + 'pipe\\:0' + "'" + ',astats=reset=1:metadata=1,aphasemeter=video=0,ebur128=metadata=1"'
    ffprobe_phase = JSON.parse(`#{ffprobe_command}`)
    out_of_phase_frames = []
    phase_frames = []
    ffprobe_phase['frames'].each do |frames|
      audiophase = frames['tags']['lavfi.aphasemeter.phase'].to_f
      phase_frames << audiophase
    end
      @average_phase = (phase_frames.sum(0.0) / phase_frames.size).round(2)
  end


  def store_hash(hash)
    @md5 = hash
  end

  def store_probe(ffprobe_out)
    @channel_one_max = ffprobe_out[0]
    @channel_two_max = ffprobe_out[1]
  end

  def store_phase(average_phase)
    @average_phase = average_phase
  end


  def output
    puts @input_path
    puts @md5
    puts @channel_one_max
    puts @channel_two_max
    puts @average_phase
  end
end

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


qc_files.each do |file|
  file.output
end