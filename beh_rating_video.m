function beh_rating_video(moviename, rating_reso, idle_time)
% beh_rating_video(moviename, rating_reso, idle_time)
% INPUT
% moviename: string of the vedio clip name
% rating reso: rating resolution in seconds
% idle_time: idle longer than idle_time the rating would be switch to baseline
% MATLAB R2018b, Psychtoolbox 3.0.15
% --
% PlayMoviesDemo
% MouseTraceDemo

if (nargin < 1) || isempty(moviename)
    moviename = [];
end

if isempty(moviename)
    moviename = 'atrium.mov';
end

if (nargin < 2) || isempty(rating_reso)
    rating_reso = 0.5; % s/meas
end

if (nargin < 3) || isempty(idle_time)
    idle_time = 5; % s
end

backgroundMaskOut = [];
tolerance = [];
pixelFormat = [];
maxThreads = [];

% Initialize with unified keynames and normalized colorspace:
PsychDefaultSetup(2);

% Setup key mapping:
esc = KbName('s');

% setting environment variables
setenv('PSYCH_ALLOW_DANGEROUS', '1')
Screen('Preference', 'SkipSyncTests', 1);

sensi = 18;

try
    % Return full list of movie files from directory+pattern:
    moviefiles = dir(moviename);
    
    if isempty(moviefiles)
        fprintf('assigned movie is not exist in the current folder!');
        error('');
    else
        moviefiles.name = fullfile(pwd,moviefiles.name);
    end
    
    % Open onscreen window with gray background:
    screen = max(Screen('Screens'));
    white = WhiteIndex(screen);
    black = BlackIndex(screen);
    win = PsychImaging('OpenWindow', screen, black);
    [width,height] = WindowSize(screen);
    [~,yy] = WindowCenter(screen);
    
    shader = [];
    if (nargin > 1) && ~isempty(backgroundMaskOut)
        shader = CreateSinglePassImageProcessingShader(win, 'BackgroundMaskOut', backgroundMaskOut, tolerance);
    end
    
    % Initial display and sync to timestamp:
    Screen('Flip',win);
    abortit = 0;
    
    % Use blocking wait for new frames by default:
    blocking = 1;
    
    % Default preload setting:
    preloadsecs = [];
    
    % Playbackrate defaults to 1:
    rate = 1;
    
    % Choose 16 pixel text size:
    Screen('TextSize', win, 16);
    
    % Endless loop, runs until ESC key pressed:
    moviename = moviefiles.name;
    
    % Show title while movie is loading/prerolling:
    DrawFormattedText(win, ['Loading ...\n' moviename], 'center', 'center', white, 40);
    Screen('Flip', win);
    
    % Open movie file and retrieve basic info about movie:
    [movie, movieduration, fps, imgw, imgh] = Screen('OpenMovie', win, moviename, [], preloadsecs, [], pixelFormat, maxThreads);
    fprintf('Movie: %s  : %f seconds duration, %f fps, w x h = %i x %i...\n', moviename, movieduration, fps, imgw, imgh);
    
    ii = 0;
    
    SetMouse(width*3/4,yy,screen);
    
    DrawFormattedText(win, 'Press any key to start', 'center', 'center', white, 40);
    Screen('Flip', win);
    KbPressWait;
    
    % Start playback of movie. This will start
    % the realtime playback clock and playback of audio tracks, if any.
    % Play 'movie', at a playbackrate = 1, with one-time loop=0 and
    % 1.0 == 100% audio volume.
    Screen('PlayMovie', movie, rate, 0, 1.0);
    
    t1 = GetSecs;
    rating = [];
    
    if rating_reso < 1/fps
        rating_reso = 1/fps;
    end
    
    rating_reso_frame = rating_reso*fps;
    idle_time_rating = round(idle_time/rating_reso);
    
    % Infinite playback loop: Fetch video frames and display them...
    while ~abortit
        
        if ~mod(ii,rating_reso_frame)
            [x,y,~] = GetMouse(screen);
            rating = cat(1,rating,-((y-yy)/height*sensi));
            if rating(end) ~= 0 && (ii/fps > idle_time)
                if length(unique(rating(end:-1:end-idle_time_rating))) == 1
                    SetMouse(x,yy,screen);
                end
            end
        end
        DrawFormattedText(win, sprintf('Rating: %d',round(rating(end))), 'center', 20, white);
        
        
        % Check for abortion:
        [keyIsDown,~,keyCode] = KbCheck;
        if (keyIsDown==1 && keyCode(esc))
            % Set the abort-demo flag.
            abortit = 1;
            break;
        end
        
        % Only perform video image fetch/drawing if playback is active
        % and the movie actually has a video track (imgw and imgh > 0):
        if ((abs(rate)>0) && (imgw>0) && (imgh>0))
            % Return next frame in movie, in sync with current playback
            % time and sound.
            % tex is either the positive texture handle or zero if no
            % new frame is ready yet in non-blocking mode (blocking == 0).
            % It is -1 if something went wrong and playback needs to be stopped:
            tex = Screen('GetMovieImage', win, movie, blocking);
            
            % Valid texture returned?
            if tex < 0
                % No, and there won't be any in the future, due to some
                % error. Abort playback loop:
                break;
            end
            
            if tex == 0
                % No new frame in polling wait (blocking == 0). Just sleep
                % a bit and then retry.
                WaitSecs('YieldSecs', 0.005);
                continue;
            end
            
            % Draw the new texture immediately to screen:
            Screen('DrawTexture', win, tex, [], [], [], [], [], [], shader);
            
            % Update display:
            Screen('Flip', win);
            
            % Release texture:
            Screen('Close', tex);
            
            % Framecounter:
            ii = ii + 1;
        end
    end
    
    telapsed = GetSecs - t1;
    fprintf('Elapsed time %f seconds, for %i frames.\n', telapsed, ii);
    
    Screen('Flip', win);
    KbReleaseWait;
    
    % Done. Stop playback:
    Screen('PlayMovie', movie, 0);
    
    % Close movie object:
    Screen('CloseMovie', movie);
    
    % Close screens.
    % return environment variables
    setenv('PSYCH_ALLOW_DANGEROUS', '0')
    Screen('Preference', 'SkipSyncTests', 0);
    sca;
    
    tt = clock;
    plot(rating)
    fn = sprintf('param-%d-%02d-%02d-%02d-%02d.mat',tt(1),tt(2),tt(3),tt(4),tt(5));
    save(fn,'rating','moviename','rating_reso','fps');
    fprintf('%s saved, bye!\n',fn);
    
    % Done.
    return;
catch %#ok<*CTCH>
    % Error handling: Close all windows and movies, release all ressources.
    sca;
end
