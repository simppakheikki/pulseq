% this is a demo low-performance EPI sequence;
% it doesn't use ramp-samping and is only good for educational purposes.
%
fov=[12e-3 20e-3]; Nx=32; Ny=2*32;       % Define FOV and resolution
thickness=0e-3;                 % slice thinckness

% Set system limits
lims = mr.opts('MaxGrad',3200,'GradUnit','mT/m', 'maxB1', 100000,...
               'MaxSlew',500000,'SlewUnit','T/m/s', ...
               'rfRingdownTime', 0e-6, 'rfDeadTime', 2e-6,...
               'blockDurationRaster', 1e-6, 'gradRasterTime', 1e-6,...
               'rfRasterTime', 1e-6, 'adcSamplesDivisor',1);

seq=mr.Sequence(lims);              % Create a new sequence object
% Create 90 degree slice selection pulse and gradient
[rf] = mr.makeSincPulse(pi/2,'system',lims,'Duration',10e-6,...
    'SliceThickness',thickness,'apodization',0,'timeBwProduct',1,...
    'use', 'excitation');
delay = 50e-6;
% Define other gradients and ADC events
deltak=1./fov;
dwellTime = 2e-6; % I want it to be divisible by 2
adc_margin = 2*dwellTime;
readoutTime = Nx*dwellTime;
gx = mr.makeTrapezoid('x',lims,'Area',Nx*deltak(1),'Duration',adc_margin+readoutTime, 'Delay', delay);
del = mr.makeDelay(135e-6);
adc = mr.makeAdc(Nx,'Duration',readoutTime,'Delay',delay+gx.riseTime+(gx.flatTime-readoutTime)/2);

% Pre-phasing gradients
gxPre = mr.makeTrapezoid('x',lims,'Area',-gx.area/2,'Duration',readoutTime/2); % removed -deltak/2 to aligh the echo between the samples
gyPre = mr.makeTrapezoid('y',lims,'Area',-(Ny/2-0.5)*deltak(2),'Duration',100e-6, 'Delay', delay);

% Phase flip in specific time
dur = 50e-6;
gy = mr.makeTrapezoid('y',lims,'Area',deltak(2),'Duration',dur, 'Delay', delay);

% Define sequence blocks
% seq.addBlock(mr.makeDelay(1)); % older scanners like Trio may need this
                                 % dummy delay to keep up with timing
seq.addBlock(rf);
seq.addBlock(gyPre);
seq.addBlock(gxPre);
for i=1:Ny
    seq.addBlock(gx,adc);           % Read one line of k-space
    seq.addBlock(del);
    seq.addBlock(gy);               % Phase blip
    gx.amplitude = -gx.amplitude;   % Reverse polarity of read gradient
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
seq.plot();

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
