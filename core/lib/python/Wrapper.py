#------------------------------------------------------------------------------
# Modules
#------------------------------------------------------------------------------

from types import BuiltinMethodType, MethodType

__all__ = ['Wrapper']


#------------------------------------------------------------------------------
# Wrapper
#------------------------------------------------------------------------------

'''
Wrapper class allowing pre- and post-function call hooks to be injected
'''
class Wrapper(object):
    def __init__(self, other):
        self.other = other

    def __getattr__(self, name):
        func = None
        if hasattr(self.other, name):
            func = getattr(self.other, name)
        if func:
            return lambda *args, **kwargs: self._wrap(func, args, kwargs)
        raise AttributeError(name)

    def _wrap(self, func, args, kwargs):
        self._wrap_pre(func, args, kwargs)
        t = type(func)
        if t == MethodType or t == BuiltinMethodType:
            ret = func(*args, **kwargs)
        else:
            ret = func(self.other, *args, **kwargs)
        self._wrap_post(func, args, kwargs)
        return ret

    def _wrap_pre(self, func, args, kwargs):
        pass

    def _wrap_post(self, func, args, kwargs):
        pass

