import {Line, Circle, Txt, makeScene2D} from '@motion-canvas/2d';
import {createRef, easeInOutCubic, waitFor, all} from '@motion-canvas/core';
export default makeScene2D(function* (view) {
  const line = createRef<Line>(); const dot = createRef<Circle>(); const text = createRef<Txt>();
  view.add(<><Line ref={line} points={[[-345, 0], [345, 0]]} stroke={'#c4ab76'} lineWidth={3} end={0} />
    <Circle ref={dot} x={345} size={16} fill={'#eee8d7'} />
    <Txt ref={text} text={'CHECKPOINT RESTORED'} y={-35} fontFamily={'sans-serif'} fontSize={60} fill={'#eee8d7'} opacity={0} /></>);
  yield* line().end(1, .8, easeInOutCubic);
  yield* waitFor(.4);
  yield* all(dot().position.x(-345, 1.1, easeInOutCubic),text().opacity(1, .5));
  yield* waitFor(2.7);
});
