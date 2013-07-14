#!/usr/bin/env ruby
require 'chingu'
include Gosu

class JezzBall < Chingu::Window

  def setup
    switch_game_state(Gameplay.new)
  end

  def needs_cursor?
    true
  end

end

class Gameplay < Chingu::GameState

  class << self
    attr_accessor :wall_create_orientation
  end


  def initialize(options = {})
    super
    @wall_create_orientation = :vertical
    self.input = { :escape => :exit, :mouse_left => :create_wall, :mouse_right => :change_dir }
    Ball.create
  end

  def create_wall
    growth_directions = case @wall_create_orientation 
    when :vertical 
      [:up, :down] 
    when :horizontal 
      [:right, :left] 
    end
    Wall.create(x: $window.mouse_x, y: $window.mouse_y, growth_directions: growth_directions)
  end

  def change_dir
    @wall_create_orientation = case @wall_create_orientation
     when :vertical
      :horizontal
     when :horizontal
      :vertical
    end
  end

  def update
    super
    Ball.each_collision(Wall) do |ball, wall|
      ball.velocity_x = - ball.velocity_x
    end
  end

end

class Ball < Chingu::GameObject
  traits :bounding_circle, :collision_detection, :velocity

  def setup
    super
    @x = $window.width / 2
    @y = $window.height / 2
    @velocity_x = 3
    @image = Image['ball.png']
    self.factor = 0.1
    cache_bounding_circle
  end

end

class Wall < Chingu::GameObject
  traits :bounding_box, :collision_detection, :timer

  def initialize(options)
    @growth_directions = options[:growth_directions]
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
      after(100) do
        Wall.create(x: new_x, y: new_y, growth_directions: new_growth_directions)
      end
    end
    cache_bounding_box
  end

end

JezzBall.new.show