import datajoint as dj
dj.config['database.host'] = 'localhost'
dj.config['database.user'] = 'ChurchlandLab_test'
dj.config['database.password'] = 'test1'
schema = dj.schema('pacman')

"LEVEL 0 ----------------------------------------------------------------------"

@schema
class BrainRegion(dj.Lookup):
    definition = """
    brain_abbrev: varchar(10) # brain region abbreviation
    ---
    brain_name: varchar(50) # full brain region last_name
    """

@schema
class EmgElectrodes(dj.Lookup):
    definition = """
    emg_electrode_abbrev: varchar(20) # unique electrode abbreviation
    ---
    emg_electrode_manufacturer: varchar(50) # electrode manufacturer
    emg_electrode_name: varchar(100) # full electrode name
    emg_electrode_channel_count: smallint unsigned # total number of active recording channels on the electrode
    """

@schema
class Experimenter(dj.Manual):
    definition = """
    experimenter_initials: char(3) # unique experimenter initials
    ---
    first_name: varchar(50) # experimenter first first_name
    middle_initial: char(1) # experimenter middle initial
    last_name: varchar(50) # experimenter last name
    """

@schema
class Monkey(dj.Manual):
    definition = """
    monkey_name: varchar(20) # unique monkey name
    ---
    """

@schema
class Muscle(dj.Lookup):
    definition = """
    muscle_abbrev: char(6) # short hand abbreviation (NameHead)
    ---
    muscle_name: varchar(30) # full muscle name
    muscle_head: varchar(30) # head of muscle
    """

@schema
class NeuralElectrodes(dj.Lookup):
    definition = """
    neural_electrode_abbrev: varchar(20) # unique electrode abbreviation
    ---
    neural_electrode_manufacturer: varchar(50) # electrode manufacturer
    neural_electrode_name: varchar(100) # full electrode name
    neural_electrode_channel_count: smallint unsigned # total number of active recording channels on the electrode
    """

"LEVEL 1 ----------------------------------------------------------------------" 

@schema
class Session(dj.Manual):
    definition = """
    -> Monkey
    ---
    -> Experimenter
    experimenter2_initials = NULL: char(3) # secondary experimenter experimenter_initials
    """
