#!/usr/bin/env ruby
require 'chingu'
require 'texplay'
include Gosu

class JezzBall < Chingu::Window

  def setup
    switch_game_state(Gameplay.new)
  end

end

class Cursor < Chingu::GameObject

  def setup
    @image = Image['mouse.png']
    self.input = { :mouse_right => :flip, :mouse_left => :create_rays }
  end

  def flip
    @angle += 90 
    @angle %= 360
  end

  def orientation
    @angle % 180 == 0 ? :vertical : :horizontal
  end

  def create_rays
    Ray.create(origin_x: $window.mouse_x, origin_y: $window.mouse_y, direction: orientation == :vertical ? :up : :left)
    Ray.create(origin_x: $window.mouse_x, origin_y: $window.mouse_y, direction: orientation == :vertical ? :down : :right)
  end

  def draw
    draw_at($window.mouse_x, $window.mouse_y)
  end

end

class Gameplay < Chingu::GameState

  def initialize(options = {})
    super
    @wall_create_orientation = :vertical
    @cursor_obj = Cursor.create(x: $window.mouse_x, y: $window.mouse_y)
    self.input = { :escape => :exit,  }
  end

  def update
    super
    Ball.each_collision(Wall) do |ball, wall|
      ball.velocity_x = - ball.velocity_x
      break # only the first collision is worth handling
    end
  end

  def draw
    $window.caption = "#{Wall.all.size} - framerate: #{$window.fps}]"
    super
  end

end

class Ball < Chingu::GameObject
  trait :bounding_circle
  traits :collision_detection, :velocity

  def setup
    super
    @x = $window.width / 2
    @y = $window.height / 2
    @velocity_x = 3
    @velocity_y = 3
    @image = Image['ball.png']
    self.factor = 0.1
    cache_bounding_circle
  end

end

class Ray < Chingu::GameObject

  attr_accessor :walls, :direction
  trait :timer
  trait :bounding_box

  RAY_THICKNESS = 10
  GROWTH_UNIT = 5

  def initialize(options = {})
    @direction = options[:direction]
    @origin_x = options[:origin_x]
    @origin_y = options[:origin_y]
    @growth = 0
    super(options.merge(x: @origin_x, y: @origin_y))
  end

  def setup
    super 
    width, height = case @direction
    when :right
      $window.width - @origin_x, RAY_THICKNESS
    when :left
      @origin_x, RAY_THICKNESS
    when :up
      RAY_THICKNESS, $window.height - @origin_y
    when :down
      RAY_THICKNESS, @origin_y
    end
    @image = TexPlay.create_image($window, width, height)
    @x += @image.width / 2 if @direction == :right
    @x -= @image.width / 2 if @direction == :left
    @y += @image.height / 2 if @direction == :down
    @y -= @image.height / 2 if @direction == :up
    every(100) do 
      @growth += GROWTH_UNIT
    end
  end

  def draw
    super
    color = [:right, :up].include?(@direction) ? :blue : :yellow
    x1, y1, x2, y2 = case @direction
    when :up, :down, :right
      0
    else
      @origin_x
    end
    x2 = case @direction 
    when :right
      @growth 
    when :left
     @origin_x - @growth
    else
      RAY_THICKNESS
    end
    y1 = case @direction
    when :right, :left, :down
      0
    else
      @origin_y
    end
    y2 = case @direction
    when :down
      @growth
    when :up
      @origin_y - @growth
    else
      RAY_THICKNESS
    end
    @image.rect(x1, y1, x2, y2, color: color, fill: true)
  end

  def bounding_box
    # TODO: make this real
    Chingu::Rect.new(@origin_x, @origin_y, @growth, RAY_THICKNESS)
  end

end

# TODO: need to know if a wall is currently being drawn (1 at a time)
#       means you need to keep track of which walls are part of "yourself" so you can delete them later 
# real concept is 2 separate rays... should you grow rays? should you keep adding sprites and then merge them after its done? 
# should you just use rects?
# Class should just create 2 rays, and keep refs to them. The 2 rays will have methods saying whether or not they are done.
# the rays will use the after type stuff

class Wall < Chingu::GameObject
  trait :bounding_box
  traits :collision_detection

  def initialize(options)
    { growth_directions: [], original: false }.merge!(options)
    @growth_directions = options[:growth_directions]
    @original = options[:original]
    super
  end

  def setup
    super
    @image = Image['wall.png']
    self.factor = 0.1
    cache_bounding_box
  end

end

JezzBall.new.show