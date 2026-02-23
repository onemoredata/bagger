
import json
import random
import time, datetime
import re

class TestLoadGenerator:
    def __init__(self, definition, seed = None,
                 words = '/usr/share/dict/words'):
        self.definition = definition
        random.seed(seed)

        self.load_words(words)

    def __iter__(self):
        return self

    def __next__(self):
        result = {}
        for obj_name in self.definition:
            val = self.generate_obj(self.definition[obj_name])
            if val is not None:
                result[obj_name] = val
        return result

    def generate_obj(self, obj):
        if obj['type'] == 'random_int':
            return self.generate_random_int(obj)
        elif obj['type'] == 'str':
            return self.generate_str(obj)
        elif obj['type'] == 'words':
            return self.generate_words(obj)
        elif obj['type'] == 'object':
            return self.generate_subobj(obj)
        else:
            return None

    def generate_subobj(self, obj):
        result = {}
        for obj_name in obj['elements']:
            result[obj_name] = self.generate_obj(obj['elements'][obj_name])
        return result
        
    def generate_random_int(self, obj):
        return random.randint(obj['min'], obj['max'])

    def generate_str(self, obj):
        r = random.random()
        s = 0.0
        values = obj['values']

        for val in values:
            if r <= (values[val] + s):
                return val
            s += values[val]

        return None

    def generate_words(self, obj):
        result = ""
        line = ""
        linelen = int(obj['linelen'])

        for i in range(obj['min'] - 1, random.randint(obj['min'], obj['max'])):
            word = self.words[random.randint(0, self.nwords - 1)]
            if len(line + " " + word) > linelen:
                if result != "":
                    result += "\n"
                result += line
                line = ""
            else:
                if line != "":
                    line += " "
                line += word
        
        if line != "":
            if result != "":
                result += "\n"
            result += line
        
        return result

    def load_words(self, words_path):
        n = 0
        words = []
        wreg = re.compile('^[a-zA-Z]+$')

        with open(words_path, 'r') as fd:
            for word in fd:
                if wreg.match(word) is not None:
                    words.append(word.strip())
                    n += 1
        
        self.words = words
        self.nwords = n

class TestLoadReader:
    def __init__(self, infd, entry_ts, timing = 1.0):
        self.infd = infd
        self.start = time.time()
        self.entry_ts = entry_ts
        if timing == 0.0:
            self.timing = -1.0
        else:
            self.timing = timing

    def __iter__(self):
        return self

    def __next__(self):
        desc = self.infd.readline()
        if desc == '':
            raise StopIteration

        ts, off, elen = desc.split()
        due = self.start + float(ts) / self.timing
        off = float(off)
        ets = datetime.datetime.fromtimestamp(due + off).isoformat()
        payload = json.loads(self.infd.read(int(elen)))
        if off != -666666.666:
            payload[self.entry_ts] = ets
        if off == -666666.999:
            payload[self.entry_ts] = 'garbage-timestamp'

        if self.timing > 0.0:
            wait = due - time.time()
            #print("now", time.time(), "ts", ts, "due", due, "wait", wait)
            if wait > 0.0:
                time.sleep(wait)

        return due, payload

