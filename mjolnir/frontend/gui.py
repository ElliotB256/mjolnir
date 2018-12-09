import zmq
import sys
import argparse
from PyQt5 import QtWidgets, QtCore
from artiq.protocols.pc_rpc import Client

from mjolnir.frontend.beam_ui import BeamDisplay
from mjolnir.test.dummy_zmq import Dummy
from mjolnir.test.dummy_cam import Dummy as DummyCam


def zmq_setup(ctx, server, port):
    sock = ctx.socket(zmq.SUB)
    sock.set_hwm(1)
    sock.connect("tcp://{}:{}".format(server, port))
    sock.setsockopt_string(zmq.SUBSCRIBE, '')
    sock.setsockopt(zmq.CONFLATE, 1)
    sock.setsockopt(zmq.RCVTIMEO, 1)
    return sock


def remote(args):
    ### Remote operation ###
    camera = Client(args.server, args.artiq_port)
    b = BeamDisplay(camera)
    ctx = zmq.Context()
    sock = zmq_setup(ctx, args.server, args.zmq_port)

    def qt_update():
        try:
            im = sock.recv_pyobj()
        except zmq.error.Again as e:
            pass
        else:
            b.queue_image(im)

    timer = QtCore.QTimer(b)
    timer.timeout.connect(qt_update)
    timer.start(50) # timeout ms


def local(args):
    ### Local operation ###
    pass


def test_dummy(args):
    camera = Dummy()
    b = BeamDisplay(camera)
    camera.register_callback(lambda im: b.queue_image(im))


def test_dummy_cam(args):
    camera = DummyCam()
    b = BeamDisplay(camera)
    camera.new_image.connect(b.queue_image)


def get_parser():
    parser = argparse.ArgumentParser(description="GUI for Thorlabs CMOS cameras")
    subparsers = parser.add_subparsers()

    remote_parser = subparsers.add_parser("remote",
        help="connect to a camera providing a ZMQ/Artiq network interface")
    remote_parser.add_argument("--server", "-s", type=str, required=True)
    remote_parser.add_argument("--artiq-port", "-p", type=int, default=4000)
    remote_parser.add_argument("--zmq-port", "-z", type=int, default=5555)
    remote_parser.set_defaults(func=remote)

    local_parser = subparsers.add_parser("local",
        help="connect directly to a local camera")
    local_parser.add_argument("--device", "-d", type=int, required=True,
        help="camera serial number")
    local_parser.set_defaults(func=local)

    test_parser = subparsers.add_parser("test",
        help="dummy camera for testing")
    test_parser.set_defaults(func=test_dummy_cam)

    return parser


def main():
    parser = get_parser()

    args = parser.parse_args()
    app = QtWidgets.QApplication(sys.argv)
    args.func(args)
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
