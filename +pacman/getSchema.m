function obj = getSchema
persistent OBJ
if isempty(OBJ)
    OBJ = dj.Schema(dj.conn, 'pacman', 'pacman_task');
end
obj = OBJ;
end
