function [trl] = createMyTrl(cfg,markerpoints,fs)

trg_times_beg(:,1) = (markerpoints-round(cfg.prestim*fs+1));
trg_times_end(:,1) = (markerpoints+round(cfg.poststim*fs));
trl = cat(2,trg_times_beg,trg_times_end,repmat(round(cfg.prestim*fs+1)+round(cfg.poststim*fs),length(markerpoints),1));
end

