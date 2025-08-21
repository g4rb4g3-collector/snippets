@Component({
  selector: 'app-tab-navigation',
  templateUrl: './tab-navigation.component.html',
  styleUrls: ['./tab-navigation.component.css'],
  animations: [
    trigger('routeAnimation', [
      transition(':increment', [
        query(':enter, :leave', style({ position: 'absolute', width: '100%' }), { optional: true }),
        group([
          query(':enter', [
            style({ transform: 'translateX(100%)' }),
            animate('300ms ease', style({ transform: 'translateX(0)' })),
          ], { optional: true }),
          query(':leave', [
            style({ transform: 'translateX(0)' }),
            animate('300ms ease', style({ transform: 'translateX(-100%)' })),
          ], { optional: true }),
        ])
      ]),
      transition(':decrement', [
        query(':enter, :leave', style({ position: 'absolute', width: '100%' }), { optional: true }),
        group([
          query(':enter', [
            style({ transform: 'translateX(-100%)' }),
            animate('300ms ease', style({ transform: 'translateX(0)' })),
          ], { optional: true }),
          query(':leave', [
            style({ transform: 'translateX(0)' }),
            animate('300ms ease', style({ transform: 'translateX(100%)' })),
          ], { optional: true }),
        ])
      ])
    ])
  ]
})
