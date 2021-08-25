#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'pry'
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
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  Dir.mkdir('output/thanks') unless Dir.exist?('output/thanks')

  filename = "output/thanks/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

peak_hash = Hash.new(0)
def update_peak_time_hash(date_time, peak_hash)
  peak_hash[Time.strptime(date_time, '%m/%d/%y %k:%M').hour] += 1
end

peak_day_hash = Hash.new(0)
def update_peak_days_hash(date_time, peak_day_hash)
  peak_day_hash[Date.strptime(date_time, '%m/%d/%y %k:%M').strftime('%A')] += 1
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

contents.each do |row|
  id = row[0]
  puts "Creating thanks_#{id}.html..."
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone = clean_phone_number(row[:homephone])
  update_peak_time_hash(row[:regdate], peak_hash)
  update_peak_days_hash(row[:regdate], peak_day_hash)
  legislators = legislators_by_zipcode(zipcode)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

peak_hours = peak_hash.select { |_k, v| v == peak_hash.values.max }
hour_erb = File.read('peak_hours.erb')
hour_template = ERB.new hour_erb
hour_html = hour_template.result(binding)
Dir.mkdir('output') unless Dir.exist?('output')
Dir.mkdir('output/hours') unless Dir.exist?('output/hours')
File.open('output/hours/peak_hours.html', 'w') do |file|
  file.puts hour_html
end

peak_days = peak_day_hash.select { |_k, v| v == peak_day_hash.values.max }
puts peak_days
day_erb = File.read('peak_days.erb')
day_template = ERB.new day_erb
day_html = day_template.result(binding)
Dir.mkdir('output') unless Dir.exist?('output')
Dir.mkdir('output/days') unless Dir.exist?('output/days')
File.open('output/days/peak_days.html', 'w') do |file|
  file.puts day_html
end
