require 'crawler_rocks'
require 'pry'
require 'json'

require 'thread'
require 'thwait'

class NckuCourseCrawler
  include CrawlerRocks::DSL

  def initialize year: current_year, term: current_term, update_progress: nil, after_each: nil, params: nil

    @query_url = "http://course-query.acad.ncku.edu.tw/qry/qry002.php"

    @year = params && params["year"].to_i || year
    @term = params && params["term"].to_i || term
    @update_progress_proc = update_progress
    @after_each_proc = after_each
  end

  def courses
    @courses = []
    @threads = []

    visit "http://course-query.acad.ncku.edu.tw/qry/index.php"
    deps_h = Hash[(@doc.css('.dept a') | @doc.css('.institute a')).map do |d|
      m = d.text.gsub(/\s+/, ' ').match(/\ \(\ (?<dep_c>.{2})\ \）(?<dep>.+)\ /)
      [m[:dep], m[:dep_c]]
    end]

    deps_h.each do |dep_n, dep_c|
      sleep(1) until (
        @threads.delete_if { |t| !t.status };  # remove dead (ended) threads
        @threads.count < (ENV['MAX_THREADS'] || 20)
      )

      @threads << Thread.new do
        puts dep_n
        r = RestClient.get "#{@query_url}?\
          dept_no=#{URI.encode(dep_c)}&\
          syear=#{(@year-1911).to_s.rjust(4, '0')}&\
          sem=#{@term}".gsub(/\s+/, '')
        doc = Nokogiri::HTML r.to_s

        doc.css('[class^=course_y]').each do |row|
          datas = row.css('td')

          serial_no = datas[2] && datas[2].text
          code = datas[3] && datas[3].text
          group_code = datas[4] && datas[4].text.strip
          gs = datas[5] && datas[5].text.split(/\s+/)
          # grade = gs[0]
          # group = gs[1]

          course_days = []
          course_periods = []
          course_locations = []

          loc = datas[17] && datas[17].text.squeeze
          datas[16].search('br').each {|br| br.replace("\n") }
          datas[16].text.strip.split("\n").each do |pss|
            pss.match(/\[(?<d>\d)\](?<ps>.+)/) do |m|
              _start = m[:ps].split('~').first
              _end = m[:ps].split('~').last
              (_start.._end).each do |period|
                course_days << m[:d]
                course_periods << period
                course_locations << loc
              end
            end
          end

          course = {
            year: @year,
            term: @term,
            department: dep_n,
            department_code: dep_c,
            code: "#{@year}-#{@term}-#{serial_no}-#{code}-#{group_code}",
            general_code: code,
            group: gs.join,
            grade: datas[6] && datas[6].text.to_i,
            name: datas[10] && datas[10].text.strip,
            url: datas[10] && !datas[10].css('a').empty? && datas[10].css('a')[0][:href],
            required: datas[11] && datas[11].text.include?('必'),
            credits: datas[12] && datas[12].text.to_i,
            lecturer: datas[13] && datas[13].text.strip,
            day_1: course_days[0],
            day_2: course_days[1],
            day_3: course_days[2],
            day_4: course_days[3],
            day_5: course_days[4],
            day_6: course_days[5],
            day_7: course_days[6],
            day_8: course_days[7],
            day_9: course_days[8],
            period_1: course_periods[0],
            period_2: course_periods[1],
            period_3: course_periods[2],
            period_4: course_periods[3],
            period_5: course_periods[4],
            period_6: course_periods[5],
            period_7: course_periods[6],
            period_8: course_periods[7],
            period_9: course_periods[8],
            location_1: course_locations[0],
            location_2: course_locations[1],
            location_3: course_locations[2],
            location_4: course_locations[3],
            location_5: course_locations[4],
            location_6: course_locations[5],
            location_7: course_locations[6],
            location_8: course_locations[7],
            location_9: course_locations[8],
          }
          @after_each_proc.call(:course => course) if @after_each_proc
          @courses << course
        end # doc.css each row
      end # end thread do
    end # deps_h.each do
    ThreadsWait.all_waits(*@threads)

    @courses
  end

  def current_year
    (Time.now.month.between?(1, 7) ? Time.now.year - 1 : Time.now.year)
  end

  def current_term
    (Time.now.month.between?(2, 7) ? 2 : 1)
  end
end

# cc = NckuCourseCrawler.new(year: 2015, term: 1)
# File.write('1041courses.json', JSON.pretty_generate(cc.courses))
