#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone)
  phone = phone.delete('^0-9').match(/^(1\d{10}|\d{10})$/).to_s
  if phone != ''
    phone = phone[-10..-1]
    [phone[0..2], phone[3..5], phone[6..-1]].join('-')
  else
    'Valid Number Not Provided!'
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    civic_info.representative_info_by_address(address: zipcode,
                                              levels: 'country',
                                              roles: %w[legislatorUpperBody
                                                        legislatorLowerBody]).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def print_filename(filename)
  puts "\e[33mCreating #{filename}\e[0m"
end

def create_erb_template(template_name)
  template = File.read(template_name)
  ERB.new template
end

def create_dir(name)
  Dir.mkdir(name) unless Dir.exist?(name)
end

def write_to_file(filename, content)
  File.open(filename, 'w') do |file|
    file.puts content
  end
end

def save_html(sub_dir, filename, content)
  create_dir('output')
  create_dir("output/#{sub_dir}")
  filename = "output/#{sub_dir}/#{filename}"
  write_to_file(filename, content)
end

def max_from_hash(hash)
  hash.select { |_k, v| v == hash.values.max }
end

def update_peak_hours_hash(date_time, peak_hash)
  peak_hash[Time.strptime(date_time, '%m/%d/%y %k:%M').hour] += 1
end

def update_peak_days_hash(date_time, peak_day_hash)
  # peak_day_hash[Date.strptime(date_time, '%m/%d/%y %k:%M').strftime('%A')] += 1
  peak_day_hash[Date::DAYNAMES[Date.strptime(date_time, '%m/%d/%y %k:%M').wday]] += 1
end

def save_peak(erb, filename, hash)
  print_filename(filename)
  peak = max_from_hash(hash)
  html = create_erb_template(erb).result(binding)
  save_html('peak', filename, html)
end

peak_hours_hash = Hash.new(0)
peak_days_hash = Hash.new(0)

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)
thanks_template = create_erb_template('form_letter.erb')

contents.each do |row|
  id = row[0]
  print_filename("thanks_#{id}.html")
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_number(row[:homephone])

  update_peak_hours_hash(row[:regdate], peak_hours_hash)
  update_peak_days_hash(row[:regdate], peak_days_hash)

  legislators = legislators_by_zipcode(zipcode)
  content = thanks_template.result(binding)

  save_html('thanks', "thanks_#{id}.html", content)
end

save_peak('peak_hours.erb', 'peak_hours.html', peak_hours_hash)
save_peak('peak_days.erb', 'peak_days.html', peak_days_hash)
