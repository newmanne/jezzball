#!/usr/bin/env ruby
require 'chingu'
require 'texplay'
include Gosu

module GridUtil

  def snap_to_grid(coord)
    coord - (coord % Gameplay::GRID_SIZE)
  end

end


class JezzBall < Chingu::Window

  def setup
    switch_game_state(Gameplay.new)
  end

end

class Cursor < Chingu::GameObject
  include GridUtil

  attr_accessor :orientation

  def setup
    @horizontal_image = TexPlay.create_image($window, 2 * Gameplay::GRID_SIZE, Gameplay::GRID_SIZE)
    @vertical_image = TexPlay.create_image($window, Gameplay::GRID_SIZE, 2 * Gameplay::GRID_SIZE)
    paint_images
    @orientation = :horizontal
    @center_x = @center_y = 0
    @image = @horizontal_image
    self.input = { :mouse_right => :flip, :mouse_left => :create_rays }
  end

  def paint_images
    @horizontal_image.rect(0, 0, Gameplay::GRID_SIZE - 1, Gameplay::GRID_SIZE - 1, color: :yellow)
    @horizontal_image.rect(Gameplay::GRID_SIZE, 0, Gameplay::GRID_SIZE * 2 - 1, Gameplay::GRID_SIZE - 1, color: :blue)
    @vertical_image.rect(0, 0, Gameplay::GRID_SIZE - 1, Gameplay::GRID_SIZE - 1, color: :yellow)
    @vertical_image.rect(0, Gameplay::GRID_SIZE, Gameplay::GRID_SIZE - 1, Gameplay::GRID_SIZE * 2 - 1, color: :blue)
  end

  def flip
    @orientation = @orientation == :vertical ? :horizontal : :vertical
    @image =  @orientation == :vertical ? @vertical_image : @horizontal_image
  end

  def create_rays
    Ray.create(origin_x: $window.mouse_x, origin_y: $window.mouse_y, direction: orientation == :vertical ? :up : :left)
    Ray.create(origin_x: $window.mouse_x, origin_y: $window.mouse_y, direction: orientation == :vertical ? :down : :right)
  end

  def update
    @x = snap_to_grid($window.mouse_x) 
    @x -= Gameplay::GRID_SIZE if @orientation == :horizontal
    @y = snap_to_grid($window.mouse_y)
    @y -= Gameplay::GRID_SIZE if @orientation == :vertical
  end

end


class Gameplay < Chingu::GameState

  include GridUtil
  GRID_SIZE = 20 # remember this must be a multiple of both resolutions
  GRID_COLOR = :red

  def initialize(options = {})
    super
    Cursor.create(x: $window.mouse_x, y: $window.mouse_y)
    self.input = { :escape => :exit }
  end

  def setup 
    @grid_image = create_grid_image
    Ball.create
    super
  end

  def create_grid_image
    TexPlay.create_image($window, $window.width, $window.height).paint {
      for i in 0..($window.width / GRID_SIZE)
        for j in 0..($window.height / GRID_SIZE)
          rect(i * GRID_SIZE, j * GRID_SIZE, (i + 1) * GRID_SIZE, (j + 1) * GRID_SIZE, color: GRID_COLOR)
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
    @grid_image.draw(0, 0, 0)
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
  include GridUtil

  attr_accessor :walls, :direction
  trait :timer
  trait :bounding_box, debug: true

  RAY_THICKNESS = Gameplay::GRID_SIZE
  GROWTH_UNIT = Gameplay::GRID_SIZE
  GROWTH_TIME = 100

  def initialize(options = {})
    @direction = options[:direction]
    @origin_x = snap_to_grid(options[:origin_x])
    @origin_y = snap_to_grid(options[:origin_y])
    @growth = 0
    @center_x = @center_y = 0 # keep origin at top left
    @complete = false
    super(options)
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
    case @direction
    when :right, :down
      @x = @origin_x
      @y = @origin_y
    when :up
      @x = @origin_x
      @y = 0
    when :left
      @x = 0
      @y = @origin_y
    end
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
    color = [:right, :down].include?(@direction) ? :blue : :yellow
    x1, y1, x2, y2 = rect_points
    @image.rect(x1, y1, x2, y2, color: color, fill: true)
    @image.draw(@x, @y, 1)
  end

  # The rectangular, with the coordinate system WITHIN the texplay image
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
    x1, y1, x2, y2 = rect_points
    width, height = [x2 - x1, y2 - y1]
    Chingu::Rect.new(@x, @y, width, height) # TODO: convert this to take care of neg values (not allowed)
  end

end

JezzBall.new.show