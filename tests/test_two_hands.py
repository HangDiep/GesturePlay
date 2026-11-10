"""Two hand roles, real tracker callback and independent gesture states."""
from types import SimpleNamespace
import unittest

from config import AppConfig
from core.hand_roles import HandRoles
from core.hand_tracker import HandTracker, landmarker_options
from core.shared_state import CameraFrame, HandResult, SharedState, TrackedHand
from hand_service.server import HandServer


def candidate(side, x, y=.5):
    return (side, (x, y), .8, ((x, y), (x+.03, y)), False, None)


class RoleTests(unittest.TestCase):
    def test_detection_order_and_label_jitter_do_not_swap_roles(self):
        roles = HandRoles()
        a, b = candidate('left', .25), candidate('right', .75)
        self.assertEqual(roles.assign([b, a], 100)['left'], a)
        a, b = candidate('right', .27), candidate('left', .73)
        result = roles.assign([b, a], 150)
        self.assertEqual(result['left'], a)
        self.assertEqual(result['right'], b)

    def test_overlap_unknown_labels_and_large_jumps_fail_closed(self):
        roles = HandRoles()
        self.assertFalse(roles.assign([candidate('', .25), candidate('', .75)], 100))
        roles.assign([candidate('left', .25), candidate('right', .75)], 150)
        self.assertFalse(roles.assign([candidate('left', .5), candidate('right', .5)], 200))
        self.assertFalse(roles.assign([candidate('left', .9, .9)], 250))
        self.assertEqual(set(roles.assign([candidate('right', .74)], 300)), {'right'})
        self.assertFalse(roles.assign([candidate('left', .26)], 299))

    def test_tracker_reports_two_hands_without_relying_on_array_order(self):
        state = SharedState()
        tracker = HandTracker(AppConfig(), state)
        stamp = tracker._remember(CameraFrame(1, 1_000_000_000, None))
        def marks(x):
            points = [SimpleNamespace(x=x, y=.5) for _ in range(21)]
            points[5].x, points[17].x = x-.03, x+.03
            points[4].x, points[8].x = x-.04, x+.04
            return points
        result = SimpleNamespace(hand_landmarks=[marks(.75), marks(.25)], handedness=[
            [SimpleNamespace(category_name='Left', score=.95)],
            [SimpleNamespace(category_name='Right', score=.95)],
        ])
        tracker._on_result(result, None, stamp)
        hand = state.snapshot().hand
        self.assertEqual({h.side for h in hand.hands}, {'left', 'right'})
        self.assertGreater(hand.palm_x, .5)
        self.assertEqual(landmarker_options(AppConfig(), lambda *_: None).num_hands, 2)
        self.assertEqual(landmarker_options(AppConfig(max_hands=1), lambda *_: None).num_hands, 1)


class DualGestureTests(unittest.TestCase):
    def test_each_hand_has_independent_hysteresis_and_lost_hand_rearms(self):
        service = HandServer()
        def packet(t, *, left=.8, right=.8, missing=False):
            now = int(t*1e9)
            hands = [TrackedHand('left', .25, .5, left, ((.2,.5),(.3,.5)))]
            if not missing:
                hands.append(TrackedHand('right', .75, .5, right, ((.7,.5),(.8,.5))))
            sample = HandResult(int(t*1000), int(t*1000), now, now, .75,.5,right,hands=tuple(hands))
            return service.two_hand_packet(sample, now, True)
        packet(1)
        p = packet(1.7)
        self.assertTrue(p['left']['ready'] and p['right']['ready'])
        p = packet(1.75, left=.1)
        self.assertTrue(p['left']['pinched'])
        self.assertFalse(p['right']['pinched'])
        p = packet(1.8, right=.1)
        self.assertFalse(p['left']['pinched'])
        self.assertTrue(p['right']['pinched'])
        self.assertFalse(packet(1.9, missing=True)['right']['valid'])
        self.assertFalse(packet(1.95)['right']['ready'])
        self.assertTrue(packet(2.6)['right']['ready'])
        sample = HandResult(2700, 2700, 2_700_000_000, 2_700_000_000,
                            hands=(TrackedHand('left',.25,.5,.8,((.2,.5),(.3,.5))),))
        self.assertFalse(service.two_hand_packet(sample,3_000_000_000,True)['left']['valid'])

    def test_calibration_targets_do_not_mix_hands(self):
        service = HandServer()
        self.assertEqual(service.calibration_targets({'target':'left'}), [service.hand_controllers['left']])
        self.assertEqual(len(service.calibration_targets({'target':'both'})), 2)
        with self.assertRaises(ValueError):
            service.calibration_targets({'target':'invalid'})

    def test_packet_exposes_calibration_status_for_each_physical_hand(self):
        service = HandServer()
        def sample(t):
            now = int(t * 1e9)
            hand = HandResult(int(t*1000), int(t*1000), now, now, .75,.5,.9,
                              hands=(TrackedHand('left',.25,.5,.7,((.2,.5),(.3,.5))),
                                     TrackedHand('right',.75,.5,.9,((.7,.5),(.8,.5)))))
            return service.two_hand_packet(hand, now, True)
        for t in (1, 1.1, 1.2, 1.3):
            sample(t)
        self.assertTrue(service.hand_controllers['left'].calibrate_open(1_300_000_000))
        packet = sample(1.35)
        self.assertEqual(packet['left']['calibration_stage'], 'opened')
        self.assertIn('Đã ghi tay mở', packet['left']['calibration_message'])
        self.assertEqual(packet['right']['calibration_stage'], 'none')
        self.assertAlmostEqual(packet['left']['ratio'], .7)
        self.assertAlmostEqual(packet['right']['ratio'], .9)


if __name__ == '__main__':
    unittest.main()
