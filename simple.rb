#!/usr/bin/env ruby
require 'chingu'
include Gosu

class JezzBall < Chingu::Window

  def setup
    switch_game_state(Gameplay.new)
  end

end

class Cursor < Chingu::GameObject

  def setup
    @image = Image['mouse.png']
    self.input = { :mouse_right => :flip, :mouse_left => :create_wall }
  end

  def flip
    @angle += 90 
    @angle %= 360
  end

  def orientation
    @angle % 180 == 0 ? :vertical : :horizontal
  end

  def create_wall
    growth_directions = case orientation 
    when :vertical 
      [:up, :down] 
    when :horizontal 
      [:right, :left] 
    end
    Wall.create(x: $window.mouse_x, y: $window.mouse_y, growth_directions: growth_directions, original: true)
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
    @cursor_obj.draw_at($window.mouse_x, $window.mouse_y)
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

# TODO: need to know if a wall is currently being drawn (1 at a time)
#       means you need to keep track of which walls are part of "yourself" so you can delete them later 
# real concept is 2 separate rays... should you grow rays? should you keep adding sprites and then merge them after its done? 
# should you just use rects?
# Class should just create 2 rays, and keep refs to them. The 2 rays will have methods saying whether or not they are done.
# the rays will use the after type stuff

class Wall < Chingu::GameObject
  trait :bounding_box
  traits :collision_detection, :timer

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
    @growth_directions.each do |dir|
      new_x, new_y = @x, @y
      new_growth_directions = [dir]
      case dir
      when :left
        new_x -= (@image.width * self.factor)
      when :right
        new_x += (@image.width * self.factor)
      when :up
        new_y -= (@image.height * self.factor)
      when :down
        new_y += (@image.height * self.factor)
      end
      if inside_window?(new_x, new_y)
        after(100) do
          Wall.create(x: new_x, y: new_y, growth_directions: new_growth_directions)
        end
      end
    end
    cache_bounding_box
  end

end

JezzBall.new.show