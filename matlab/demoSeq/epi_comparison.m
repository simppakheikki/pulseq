% this is a demo low-performance EPI sequence for comparison
% it doesn't use ramp-samping and is only good for educational purposes.
%
fov=[14e-3 12e-3]; Nx=32; Ny=32;       % Define FOV and resolution
thickness=0e-3;                 % slice thinckness

% Set system limits
lims = mr.opts('MaxGrad',3200,'GradUnit','mT/m', 'maxB1', 100000,...
               'MaxSlew',500000,'SlewUnit','T/m/s', ...
               'rfRingdownTime', 0e-6, 'rfDeadTime', 2e-6,...
               'blockDurationRaster', 1e-6, 'gradRasterTime', 2e-6,...
               'rfRasterTime', 1e-6, 'adcSamplesDivisor',2);

seq=mr.Sequence(lims);              % Create a new sequence object
% Create 90 degree slice selection pulse and gradient
[rf] = mr.makeBlockPulse(pi,'system',lims,'Duration',10e-6,...
    'timeBwProduct',1,'use', 'excitation');
dead_time = 2e-6;
echo_time = 400e-6;
repeatition_time = 250e-6;
% Define other gradients and ADC events
deltak=1./fov;
dwellTime = 2e-6; % I want it to be divisible by 2
readoutTime = Nx*dwellTime;
phasepretime = 100e-6;
phasetime = 50e-6;
gx = mr.makeTrapezoid('x',lims,'Amplitude', Nx*deltak(1)/readoutTime,'Duration',3*dead_time+readoutTime);

% Pre-phasing gradients
gxPre = mr.makeTrapezoid('x',lims,'Amplitude', -Nx*deltak(1)/readoutTime,'Duration',2*dead_time+readoutTime/2,...
    'Delay',echo_time-rf.center-readoutTime-dead_time-gx.riseTime); % removed -deltak/2 to aligh the echo between the samples
gyPre = mr.makeTrapezoid('y',lims,'Amplitude',-(Ny+1)/2*deltak(2)/phasepretime,'Duration',phasepretime,...
    'Delay',echo_time-rf.center-readoutTime-phasepretime-dead_time);
delPre = mr.makeDelay(repeatition_time-readoutTime/2-phasetime-2*gx.riseTime);
adcPre = mr.makeAdc(Nx,'Duration',readoutTime,'Delay',dead_time);


% Phase flip in specific time
gxd = mr.makeTrapezoid('x',lims,'Amplitude', -gx.amplitude,'Duration',3*dead_time+readoutTime,...
    'Delay',phasetime);
adc = mr.makeAdc(Nx,'Duration',readoutTime,'Delay',phasetime+dead_time);
gy = mr.makeTrapezoid('y',lims,'Area',deltak(2),'Duration',phasetime+gx.riseTime);
del = mr.makeDelay(repeatition_time-phasetime-readoutTime-2*dead_time-gx.riseTime);

% Define sequence blocks
% seq.addBlock(mr.makeDelay(1)); % older scanners like Trio may need this
                                 % dummy delay to keep up with timing
seq.addBlock(rf);
seq.addBlock(gyPre,gxPre);
seq.addBlock(gx,adcPre);
seq.addBlock(delPre);
for i=1:Ny-1
    seq.addBlock(gxd,gy,adc);               % Phase blip
    seq.addBlock(del);
    gxd.amplitude = -gxd.amplitude;   % Reverse polarity of read gradient
end
TR_1slice=seq.duration; % note the actual TR per slice

%% check whether the timing of the sequence is correct
[ok, error_report]=seq.checkTiming;

if (ok)
    fprintf('Timing check passed successfully\n');
else
    fprintf('Timing check failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end

%% Plot sequence waveforms
%seq.plot();

seq.plot('stacked',1,'timeRange',[0 TR_1slice], 'timeDisp','ms'); % niceer plot for the 1st sclice

%% trajectory calculation
[ktraj_adc, t_adc, ktraj, t_ktraj, t_excitation, t_refocusing] = seq.calculateKspacePP();

% plot k-spaces
figure; plot(t_ktraj, ktraj'); % plot the entire k-space trajectory
hold; plot(t_adc,ktraj_adc(1,:),'.'); % and sampling points on the kx-axis
figure; plot(ktraj(1,:),ktraj(2,:),'b'); % a 2D plot
axis('equal'); % enforce aspect ratio for the correct trajectory display
hold; plot(ktraj_adc(1,:),ktraj_adc(2,:),'r.');

seq.write('examples/example_data/sequences/epi_single_slice.seq');   % Output sequence for scanner
% seq.sound(); % simulate the seq's tone
