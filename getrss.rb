require 'date'
require 'rss'
require 'mysql2'
require 'active_record'
require 'activerecord-import'
require 'yaml'
require 'open-uri'
require 'nokogiri'
require 'openssl'
require 'pp'
require 'fileutils'
require 'digest/md5'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

config = YAML.load_file('database.yml')
ActiveRecord::Base.establish_connection(config['db']['development'])
class Item < ActiveRecord::Base
  validates_presence_of :title
  validates_presence_of :link
  validates_uniqueness_of :link
end

class ManageRss

  @@lists = [
    'http://b.hatena.ne.jp/entrylist?sort=hot&threshold=100&mode=rss'
  ]

  @@opt = {
    'User-Agent' => 'Opera/9.80 (Windows NT 5.1)'
  }

  def getRss
    insertData = []

    @@lists.each do |list|
      open(list, @@opt) do |rss|
        rssdata = RSS::Parser.parse(rss)
        begin
          rssdata.items.each do |entry|
            tmpdate = entry.respond_to?(:pubDate) ? entry.pubDate : entry.dc_date
            item = Item.new
            item.title = entry.title
            item.link = entry.link
            item.description = entry.description
            item.entrydate = tmpdate
            item.thumbnail = getImage(entry.link)
            insertData << item
          end
        rescue => e
          pp e
        end
      end
    end

    # BULK INSERT
    Item.import insertData
    return true
  end

  private
    def getImage(url)
      charset = nil
      html = open(url, @@opt) do |f|
        charset = f.charset
        f.read
      end

      doc = Nokogiri::HTML.parse(html, charset)
      imgUrl = doc.css('//meta[property="og:image"]/@content').to_s

      fileExt = File.extname(imgUrl)
      if fileExt.empty?
        return ''
      end

      fileNameWithoutExt = File.basename(imgUrl, fileExt)
      fileName =  Digest::MD5.hexdigest(Time.now.usec.to_s + fileNameWithoutExt).to_s + fileExt
      dirName = File.dirname(__FILE__) + '/img/' + Time.now.strftime("%Y/%m/").to_s
      relativePath = 'img/' + Time.now.strftime("%Y/%m/").to_s + fileName
      filePath = dirName + fileName

      # create folder if not exist
      FileUtils.mkdir_p(dirName) unless FileTest.exist?(dirName)

      open(filePath, 'wb') do |output|
        open(imgUrl) do |data|
          output.write(data.read)
        end
      end
      return relativePath
    end
end

managerss = ManageRss.new
managerss.getRss
