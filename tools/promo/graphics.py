"""Manim comparison overlay, preserving the underlying captured screen pixels."""
from manim import Scene, Line, Arrow, Dot, Create, FadeIn, config, WHITE
config.background_color = '#141915'


class ComparisonDivider(Scene):
    def construct(self):
        edge=config.frame_width/2
        height=config.frame_height/2
        line=Line([edge, height, 0], [edge, -height, 0], color=WHITE, stroke_width=3)
        self.add(line)
        self.wait(2)
        cubic=lambda t:4*t*t*t if t<.5 else 1-(-2*t+2)**3/2
        self.play(line.animate.shift([-2*edge,0,0]),run_time=3.6,rate_func=cubic)
        self.wait(4.4)


class EngineLink(Scene):
    def construct(self):
        edge=config.frame_width*.32
        line=Arrow([-edge,0,0],[edge,0,0],buff=.08,color='#c4ab76',stroke_width=4)
        left=Dot([-edge,0,0],radius=.035,color=WHITE)
        right=Dot([edge,0,0],radius=.035,color=WHITE)
        self.add(left)
        self.play(Create(line),run_time=1.1)
        self.play(FadeIn(right),run_time=.3)
        self.wait(3.6)
