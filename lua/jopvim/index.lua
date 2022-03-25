local cache = require('jopvim.cache')
local api = require('jopvim.api')
local util = require('jopvim.util')

local M = {}

local function getFullFolderName(index, id)
  if index[id] == nil then
    return ''
  end
  if index[id].fullname == nil then
    local parent_name = getFullFolderName(index, index[id].parent_id)
    local fullname = index[id].title
    if parent_name ~= '' then
      fullname = parent_name .. '/' .. fullname
    end
    index[id].fullname = fullname
  end
  return index[id].fullname
end

local function getFolderName(index, id)
  if index[id] == nil then return '' end
  return index[id].title
end

local function saveIndex(index)
  local encoded = vim.fn.json_encode(index)
  local index_path = util.joinPath(vim.fn.stdpath("cache"), "jop", 'notes.index')
  cache.saveToCache(index_path, encoded)
end

M.get = function()
  local index = cache.getCache('notes.index', true)
  return index
end

M.update = function()
  -- Mon 11:32:41 14 Mar 2022
  -- not sure how to do this better
  -- fetch all the folders first
  local index = api.getAllFolders()
  -- for each of the folders, we set the full title
  for id in pairs(index) do
    -- just precompute all the folder name
    getFullFolderName(index, id)
  end
  local notesIndex = {}
  -- for each folder, also index the notes in it
  for id in pairs(index) do
    local notes = api.getNotesInFolder(id)
    for nid in pairs(notes) do
      notesIndex[nid] = notes[nid]
    end
  end

  for nid in pairs(notesIndex) do
    index[nid] = notesIndex[nid]
    index[nid].type = 1
    local fparent = getFullFolderName(index, notesIndex[nid].parent_id)
    local parent = getFolderName(index, notesIndex[nid].parent_id)
    local fullname = notesIndex[nid].title
    if fparent ~= nil then fullname = fparent .. "/" .. fullname end
    index[nid].fullname = fullname
    index[nid].parentname = parent
  end
  saveIndex(index)
end

M.refreshNote = function(nid, note)
  local index = M.get()
  -- check if the note exists
  if note == nil then -- note got deleted ?
    if index[nid] == nil then return end
    index[nid] = nil
  else
    -- we need to add more metadata to the notes
    -- if there is no parent_id in note, we will assume it is the same
    local prev = index[nid] or nil
    if note.parent_id == nil and prev ~= nil then
      note.parent_id = prev.parent_id
    end
    local fparent = getFullFolderName(index, note.parent_id)
    local parent = getFolderName(index, note.parent_id)
    local fullname = note.title

    if fparent ~= nil then fullname = fparent .. "/" .. fullname end

    -- @todo: perhaps should move this to a common function
    index[nid] = {
      id = nid, fullname = fullname, parentname = parent, type = 1,
      parent_id = note.parent_id, title = note.title
    }
  end
  saveIndex(index)
end

return M
