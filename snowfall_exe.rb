#!/usr/bin/env ruby
# coding: utf-8

require "rubygems"
require 'tempfile'
require 'uri'
require 'open-uri'
require 'chatterbot/dsl'
require "rmagick"
include Magick

FRAMES = 30
FLAKES = ["1.png", "2.png", "3.png"]

MIN_FLAKES = 50
MAX_FLAKES = 100

def save_to_tempfile(url, ext)
  url = "#{url}:small"
  url = url.gsub(/^http:/, "https:")

  uri = URI.parse(url)

  dest = File.join "/tmp", Dir::Tmpname.make_tmpname(['snow', ext], nil)

  puts "#{url} -> #{dest}"

  open(dest, 'wb') do |file|
    file << open(url).read
  end
  dest
end



use_streaming true

home_timeline do |tweet|
  next if tweet.retweeted_status? || tweet.text !~ /snowfall_exe/i || ! tweet.media?

  puts tweet.media.first.attrs.inspect
  source = tweet.media.first.media_url

  f = save_to_tempfile(source, File.extname(tweet.media.first.media_url))
  puts f    

  dest = make_it_snow(f)

  puts "tweet #{dest} to user"
  
  target = tweet_user(tweet)
  response = "snow!"
  begin
    client.update_with_media(
      "#{target} #{response}",
      File.open(dest),
      in_reply_to_status_id:tweet.id
    )
  rescue StandardError => e
    puts e.inspect
  end
  puts "done!"
end



class Flake
  attr_accessor :x, :y, :wiggle, :size

  def initialize(w, h)
    @width = w
    @height = h
    @x = rand(0..@width)
    @y = rand(0..@height)
    @step = @height/FRAMES

    @img = Image.read(FLAKES.sample).first
    @scale = rand(5..25)
    @img.scale!(@scale.to_f/100)

    @wiggle = rand(-15..15)
  end

  def step
    @y = @y + @step
    if @y > @height
      @y = 1
    end

    pct = @y.to_f/@height
    @offset = @wiggle * Math.sin(Math::PI * pct)
  end

  def draw(i)
    i.composite!(@img, @x + @offset, @y, OverCompositeOp)
  end
end


def make_it_snow(src)
  @src = Image.read(src).first

  @width = @src.columns
  @height = @src.rows

  flakes = 1.upto( rand(MIN_FLAKES..MAX_FLAKES) ).collect {
    Flake.new(@width, @height)
  }

  gif = ImageList.new

  FRAMES.times do |i|
    i = @src.dup
    
    flakes.each { |f|
      f.step
      f.draw(i)
    }
    gif << i
  end

  dest = File.join "/tmp", Dir::Tmpname.make_tmpname(['output', '.gif'], nil)
  gif.delay = 20
  gif.deconstruct.write(dest)

  dest
end

#if __FILE__ == $0
#  puts make_it_snow("flea.png")
#end
