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
    self.factor = 0.1
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

  GRID_SIZE = 20

  def initialize(options = {})
    super
    Cursor.create(x: $window.mouse_x, y: $window.mouse_y)
    self.input = { :escape => :exit,  }
  end

  def setup
    # Ball.create
    @image = create_grid_image
    @cursor_highlight = TexPlay.create_image($window, GRID_SIZE, GRID_SIZE)
    super
  end

  def create_grid_image
    TexPlay.create_image($window, $window.width, $window.height).paint {
      for i in 0..($window.width / GRID_SIZE)
        for j in 0..($window.height / GRID_SIZE)
          rect(i * GRID_SIZE, j * GRID_SIZE, (i + 1) * GRID_SIZE, (j + 1) * GRID_SIZE, color: :red)
        end
      end
    }
  end

  def update
    super
    Ball.each_collision(Ray) do |ball, ray|
      # TODO: this doesn't account for hitting the tip
      if [:left, :right].include?(ray.direction)
        ball.velocity_y = - ball.velocity_y
      else
        ball.velocity_x = - ball.velocity_x
      end
      unless ray.completed?
        ray.destroy
      end
    end
  end

  def draw
    # TODO: highlight the grid your mouse is hovering over
    @cursor_highlight.rect(0, 0, GRID_SIZE - 1, GRID_SIZE - 1, color: :green).draw($window.mouse_x - ($window.mouse_x % GRID_SIZE) , $window.mouse_y - ($window.mouse_y % GRID_SIZE), 2)
    @image.draw(0, 0, 1)
    $window.caption = "framerate: #{$window.fps}]"
    super
  end

  def on_complete_ray(ray)
    # TODO: check if the ray's collectively wall off an area. If they do, then do the thing
  end

end

class Ball < Chingu::GameObject
  trait :bounding_circle, debug: true
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

  def update
    if outside_window?
      @x = $window.width / 2
      @y = $window.height / 2
    end
  end

end

class Ray < Chingu::GameObject

  attr_accessor :walls, :direction
  trait :timer
  trait :bounding_box, debug: true

  RAY_THICKNESS = 10
  GROWTH_UNIT = 5
  GROWTH_TIME = 100

  def initialize(options = {})
    @direction = options[:direction]
    @origin_x = options[:origin_x]
    @origin_y = options[:origin_y]
    @growth = 0
    @complete = false
    super(options.merge(x: @origin_x, y: @origin_y))
  end

  def setup
    super 
    width, height = case @direction
    when :right
      [$window.width - @origin_x, RAY_THICKNESS]
    when :left
      [@origin_x, RAY_THICKNESS]
    when :down
      [RAY_THICKNESS, $window.height - @origin_y]
    when :up
      [RAY_THICKNESS, @origin_y]
    end
    @image = TexPlay.create_image($window, width, height)
    @x += @image.width / 2 if @direction == :right
    @x -= @image.width / 2 if @direction == :left
    @y += @image.height / 2 if @direction == :down
    @y -= @image.height / 2 if @direction == :up
    every(GROWTH_TIME) do # TODO: stop this
      @growth += GROWTH_UNIT
      if ([:right, :left].include?(@direction) and @growth > @image.width) or ([:up, :down].include?(@direction) and @growth > @image.height)
        @complete = true
        @parent.on_complete_ray(self)
      end
    end
  end

  def update
    super
    if @complete
      stop_timers
    end
  end

  def draw
    super
    color = [:right, :up].include?(@direction) ? :blue : :yellow
    x1, y1, x2, y2 = rect_points
    @image.rect(x1, y1, x2, y2, color: color, fill: true)
  end

  def rect_points
    case @direction
    when :up
      [0, @origin_y, RAY_THICKNESS, @origin_y - @growth]
    when :down
      [0, 0, RAY_THICKNESS, @growth]
    when :left
      [@origin_x, 0, @origin_x - @growth, RAY_THICKNESS]
    when :right
      [0, 0, @growth, RAY_THICKNESS]
    end
  end

  def completed?
    @complete
  end

  def bounding_box
    # TODO: clean this up
    x1, y1, x2, y2 = rect_points
    width, height = [x2 - x1, y2 - y1]
    case @direction
    when :right
      Chingu::Rect.new(@x - (@image.width / 2), @y - (@image.height / 2), width, height)
    when :left
      Chingu::Rect.new(@x + (@image.width / 2) + width, @y - (@image.height / 2), width.abs , height)
    when :down
      Chingu::Rect.new(@x - (@image.width / 2), @y - (@image.height / 2), width , height)
    when :up
      Chingu::Rect.new(@x - (@image.width / 2), @y + (@image.height / 2) + height, width , height.abs)
    end
  end

end

JezzBall.new.show