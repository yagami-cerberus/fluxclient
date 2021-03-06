
from libc.math cimport isnan, NAN
from libcpp cimport bool
from libcpp.string cimport string
from libcpp.vector cimport vector
from libcpp.pair cimport pair
from _toolpathlib cimport (ToolpathProcessor as _ToolpathProcessor,
                           GCodeParser as _GCodeParser,
                           GCodeMemoryWriter as _GCodeMemoryWriter,
                           GCodeFileWriter as _GCodeFileWriter,
                           FCodeV1MemoryWriter as _FCodeV1MemoryWriter,
                           FCodeV1FileWriter as _FCodeV1FileWriter,
                           PythonToolpathProcessor)


cdef class ToolpathProcessor:
    cdef _ToolpathProcessor *_proc

    def __dealloc__(self):
        if self._proc:
            del self._proc
            self._proc = NULL

    cpdef moveto(self, float feedrate=NAN,
                 float x=NAN, float y=NAN, float z=NAN,
                 float e0=NAN, float e1=NAN, float e2=NAN):
        cdef int flags = 0
        if not isnan(feedrate):
            flags |= 64;
        if not isnan(x):
            flags |= 32;
        if not isnan(y):
            flags |= 16;
        if not isnan(z):
            flags |= 8;
        if not isnan(e0):
            flags |= 4;
        if not isnan(e1):
            flags |= 2;
        if not isnan(e2):
            flags |= 1;
        self._proc.moveto(flags, feedrate, x, y, z, e0, e1, e2)

    cpdef sleep(self, float seconds):
        self._proc.sleep(seconds)

    cpdef enable_motor(self):
        self._proc.enable_motor()

    cpdef disable_motor(self):
        self._proc.disable_motor()

    cpdef pause(self, bool to_standby_position):
        self._proc.pause(to_standby_position)

    cpdef home(self):
        self._proc.home()

    cpdef set_toolhead_heater_temperature(self, float temperature, bool wait):
        self._proc.set_toolhead_heater_temperature(temperature, wait)

    cpdef set_toolhead_fan_speed(self, float strength):
        self._proc.set_toolhead_fan_speed(strength)

    cpdef set_toolhead_pwm(self, float strength):
        self._proc.set_toolhead_pwm(strength)

    cpdef append_comment(self, comment):
        cdef bytes c = comment.encode()
        self._proc.append_comment(c, len(c))

    cpdef on_error(self, bool critical, str message):
        cdef bytes cmessage = message.encode()
        self._proc.on_error(critical, cmessage, len(cmessage))

    cpdef terminated(self):
        self._proc.terminated()


cdef class PyToolpathProcessor(ToolpathProcessor):
    cdef object pvgc

    def __init__(self, callback):
        self.pvgc = callback
        self._proc = <_ToolpathProcessor*>new PythonToolpathProcessor(self.pvgc)


cdef class GCodeMemoryWriter(ToolpathProcessor):
    def __init__(self):
        self._proc = <_ToolpathProcessor*>new _GCodeMemoryWriter()

    def get_buffer(self):
        # TODO
        # cdef const string& swap = (<_GCodeMemoryWriter*>self._proc).get_buffer()
        # return swap.c_str()[:swap.size()]
        cdef string swap = (<_GCodeMemoryWriter*>self._proc).get_buffer()
        return swap.c_str()[:swap.size()]


cdef class GCodeFileWriter(ToolpathProcessor):
    def __init__(self, filename):
        self._proc = <_ToolpathProcessor*>new _GCodeFileWriter(filename.encode())


cdef class FCodeV1MemoryWriter(ToolpathProcessor):
    cdef string headtype
    cdef vector[pair[string, string]] metadata
    cdef vector[string] previews

    def __init__(self, head_type, metadata, previews):
        self.headtype = head_type.encode()
        self.metadata = ((k.encode(), v.encode()) for k, v in metadata.items())
        self.previews = previews
        self._proc = <_ToolpathProcessor*>new _FCodeV1MemoryWriter(&self.headtype,
            &self.metadata, &self.previews)

    def get_buffer(self):
        # TODO
        # cdef const string& swap = (<_FCodeV1MemoryWriter*>self._proc).get_buffer()
        # return swap.c_str()[:swap.size()]
        cdef string swap = (<_FCodeV1MemoryWriter*>self._proc).get_buffer()
        return swap.c_str()[:swap.size()]

    def set_metadata(self, metadata):
        self.metadata = ((k.encode(), v.encode()) for k, v in metadata.items())
        (<_FCodeV1MemoryWriter*>self._proc).metadata = &self.metadata

    def set_previews(self, previews):
        self.previews = previews
        (<_FCodeV1MemoryWriter*>self._proc).previews = &self.previews

    def get_metadata(self):
        return dict(self.metadata)

    def errors(self):
        return (<_FCodeV1MemoryWriter*>self._proc).errors


cdef class FCodeV1FileWriter(ToolpathProcessor):
    cdef string filename, headtype
    cdef vector[pair[string, string]] metadata
    cdef vector[string] previews

    def __init__(self, filename, head_type, metadata, previews):
        self.filename = filename.encode()
        self.headtype = head_type.encode()
        self.metadata = ((k.encode(), v.encode()) for k, v in metadata.items())
        self.previews = previews
        self._proc = <_ToolpathProcessor*>new _FCodeV1FileWriter(self.filename.c_str(), &self.headtype,
            &self.metadata, &self.previews)

    def set_metadata(self, metadata):
        self.metadata = ((k.encode(), v.encode()) for k, v in metadata.items())
        (<_FCodeV1FileWriter*>self._proc).metadata = &self.metadata

    def set_previews(self, previews):
        self.previews = previews
        (<_FCodeV1FileWriter*>self._proc).previews = &self.previews

    def get_metadata(self):
        return dict(self.metadata)

    def errors(self):
        return (<_FCodeV1FileWriter*>self._proc).errors


cdef class GCodeParser:
    cdef _GCodeParser *_parser

    def __cinit__(self):
        self._parser = new _GCodeParser()

    def __dealloc__(self):
        del self._parser

    cdef set_c_processor(self, _ToolpathProcessor *proc):
        self._parser.set_processor(proc)

    cpdef set_processor(self, ToolpathProcessor py_proc):
        self.set_c_processor(py_proc._proc)

    cpdef parse_command(self, bytes command):
        self._parser.parse_command(command, len(command))

    cpdef parse_from_file(self, filename):
        self._parser.parse_from_file(filename.encode())
