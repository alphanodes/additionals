# frozen_string_literal: true

# see https://github.com/nagix/chartjs-plugin-colorschemes
# see https://nagix.github.io/chartjs-plugin-colorschemes/colorchart.html
#
# this script requires:
# on macos: brew install yamllint
# on debian: apt-get install yamllint

require 'fileutils'

target_file = '../config/colorschemes.yml'
working_path = '/tmp/colorchemes'
colorschemes_files = [{ name: 'brewer', src: "#{working_path}/src/colorschemes/colorschemes.brewer.js" },
                      { name: 'office', src: "#{working_path}/src/colorschemes/colorschemes.office.js" },
                      { name: 'tableau', src: "#{working_path}/src/colorschemes/colorschemes.tableau.js" }]

FileUtils.rm_rf working_path
system "git clone https://github.com/nagix/chartjs-plugin-colorschemes.git #{working_path}"

File.open target_file, 'w' do |file|
  file.write "---\n"
  colorschemes_files.each do |color_scheme_file|
    file.write "#{color_scheme_file[:name].capitalize}:\n"
    File.readlines(color_scheme_file[:src]).each do |line|
      parts = line.split(/\s+=\s+\[/)
      next unless parts.count == 2

      file.write "  - #{color_scheme_file[:name]}.#{parts.first.strip}\n"
    end
  end
end

puts 'YAML syntax OK' if system "yamllint #{target_file}"
