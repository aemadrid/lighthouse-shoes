Shoes.setup do
  gem 'xml-simple'
  gem 'rio'
end

require 'lighthouse'
require 'rio'

Shoes.app :title => "Tickets", :width => 150, :height => 500, :resizable => true do
  
  REFRESH_PERIOD = 5  # minutes
  FRESH_PERIOD   = 45 # minutes
  
  @refreshing = false
  
  style(Shoes::Code, :weight => "bold", :stroke => "#C30")
  style(Shoes::Link, :stroke => white, :fill => nil, :underline => false)
  style(Shoes::LinkHover, :stroke => black, :fill => nil, :underline => false)
  style(Shoes::Para, :size => 9, :stroke => "#332")
  style(Shoes::Tagline, :size => 12, :weight => "bold", :stroke => "#eee", :margin => 6)

  background "#ddd".."#fff", :angle => 90
  
  @title_stack = stack do
    background black
    @subtitle = para("Acme Inc.", :stroke => "#eee", :margin_top => 8, :margin_left => 17, :margin_bottom => 0, :size => 8)
    @title = title("Tickets", :stroke => white, :margin => 4, :margin_left => 14, :margin_top => 0, :weight => "bold", :size => 24)
    background "rgb(66, 66, 66, 180)".."rgb(0, 0, 0, 0)", :height => 0.7
    background "rgb(66, 66, 66, 100)".."rgb(255, 255, 255, 0)", :height => 10, :bottom => 0
  end
  
  @tickets_stack = stack :width => 1.0, :margin_top => 6
  
  def load
    @conn = Lighthouse::Connector.new("__MY_LIGHTHOUSE_USERNAME__", "__MY_LIGHTHOUSE_TOKEN__")
    @tickets_stack.append do
      para "\n\nLoading...\n\n", :align => "center"
      timer(5) { refresh }
    end
    #@conn.projects(true)
  end
  
  def refresh
    Thread.start do
      @refreshing = true
      @conn.projects(true)
      @conn.save
      @ticket_count = 0
      @tickets_stack.clear do
        @conn.open_projects.each do |project|
          stack(:margin => 3, :margin_left => 6) do
            stack :margin_top => 4, :margin_bottom => 0 do
              background "#333".."#666", :curve => 3, :angle => 90
              tagline link(project.name, :click => project.url, :stroke => white), :size => 9, :margin => 4, :margin_left => 4
            end
            stack :margin_left => 6 do
              project.open_tickets.each do |ticket|
                stack :margin => 2, :margin_top => 3 do
                  background '#BAAA82'..'#D7C693', :curve => 3, :angle => 90 if ticket.fresh?(FRESH_PERIOD)
                  background '#999'..'#D2D2D2', :curve => 3, :angle => 90 unless ticket.fresh?(FRESH_PERIOD)
                  para link(ticket.title, :click => ticket.url, :stroke => '#323221'), :size => 7, :margin_left => 4, :margin => 3
                end
                @ticket_count += 1
              end
            end
          end
        end
        para "\nLast updated at ", @conn.last_updated.strftime("%H:%M:%S"), :size => 7, :align => "center" if @conn.last_updated
        button("Refresh Now", :align => "center", :width => 1.0) { refresh }
        @refreshing = false
      end
    end
  end
  
  def is_refresh_time?
    now = Time.now
    ((now.hour * 60 + now.min) % REFRESH_PERIOD) == 0 && now.sec == 0
  end
  
  load
  
  animate(1) do
    refresh if not @refreshing and is_refresh_time?
  end
  
end