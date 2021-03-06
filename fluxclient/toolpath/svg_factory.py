
from lxml import etree as ET  # noqa

from fluxclient.laser.laser_base import LaserBase
from fluxclient.utils.svg_parser import SVGParser


class SvgImage(object):
    _preview_buf = None
    _coordinate_set = False

    buf = None
    viewbox_width = viewbox_height = None
    x1 = x2 = y1 = y2 = rotation = None

    def __init__(self, buf):
        self.set_svg(buf)

    def set_svg(self, buf):
        errors, result = SVGParser.preprocess(buf)
        if errors and errors[-1] == "EMPTY":
            raise RuntimeError("EMPTY")
        self.errors = errors
        self.buf, self.viewbox_width, self.viewbox_height = result

    def set_preview(self, preview_size, buf):
        self._preview_width, self._preview_height = preview_size
        self._preview_buf = buf

    def set_image_coordinate(self, point1, point2, rotation):
        self._coordinate_set = True

        self.x1, self.y1 = point1
        self.x2, self.y2 = point2
        self.rotation = rotation


class SvgFactory(object):
    def __init__(self, radius=85):
        self._magic = LaserBase()
        self._magic.pixel_per_mm = 10
        self._magic.radius = radius
        self._magic.shading = False

        self._svg_images = []

    @property
    def radius(self):
        return self._magic.radius

    def add_image(self, svg_image):
        self._svg_images.append(svg_image)

    def generate_preview(self):
        for img in self._svg_images:
            if img._preview_buf:
                self._magic.add_image(img._preview_buf,
                                      img._preview_width, img._preview_height,
                                      img.x1, img.y1, img.x2, img.y2,
                                      img.rotation, 100)
        return self._magic.dump(mode="preview")

    def walk(self, progress_callback=lambda p: None):
        images_length = len(self._svg_images)

        for index, image in enumerate(self._svg_images, start=1):
            progress_callback((index - 0.5) / images_length)

            svg_data = image.buf.decode('utf8')
            root = ET.fromstring(svg_data)
            viewbox = list(
                map(float, root.attrib['viewBox'].replace(',', ' ').split())
            )

            path_data = SVGParser.elements_to_list(root)
            progress_callback(index / images_length)

            for each_path in SVGParser.process(path_data, (None, None,
                                                           image.x1, image.y1,
                                                           image.x2, image.y2,
                                                           image.rotation),
                                               viewbox, self.radius):
                # flag that means extruder should move to rather than drawto
                src_xy = None
                move_to = True
                for x, y in each_path:
                    if x == '\n':
                        move_to = True
                    else:
                        if move_to:
                            src_xy = (x, y)
                            move_to = False
                        else:
                            next_xy = (x, y)
                            yield src_xy, next_xy
                            src_xy = next_xy
